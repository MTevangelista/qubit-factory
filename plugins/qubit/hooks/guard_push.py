#!/usr/bin/env python3
"""Regra de push do hook de guarda da fábrica (chamado pelo guard.sh).

Lê o JSON do evento PreToolUse no stdin. Push comum é permitido. Sai com 2, e o motivo no
stdout, quando o comando Bash contém um `git push` que:
  - força a história (-f, --force, --force-with-lease, --force-if-includes, +refspec);
  - publica tudo de uma vez (--all, --branches, --mirror);
  - tem como destino uma branch protegida (master, main e FACTORY_BASE_BRANCH);
  - não diz a branch e a branch atual é protegida, ou não dá para descobrir qual é.

Só olha o texto do comando: barra engano, não quem quer burlar (alias, script, variável).
A proteção de verdade da branch base fica no remoto (branch protegida).
"""
import json
import os
import re
import shlex
import subprocess
import sys

PROTECTED = {"master", "main"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
# Opções globais do git que consomem o próximo token.
GIT_VALUE_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
                  "--super-prefix", "--config-env", "--attr-source"}
# Opções do push que consomem o próximo token.
PUSH_VALUE_OPTS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec",
                   "--recurse-submodules"}
FORCE_OPTS = ("--force", "--force-with-lease", "--force-if-includes")
BULK_OPTS = {"--all", "--branches", "--mirror"}
CONTROL = set(";|&()\n")


def tokenize(cmd):
    """Tokens do shell; operadores de controle e redirecionamentos viram tokens próprios."""
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars="();<>|&\n")
        lex.whitespace = " \t\r"
        lex.whitespace_split = True
        lex.commenters = ""
        return list(lex)
    except ValueError:  # aspas sem par (heredoc etc.): divisão simples, sem interpretar aspas
        return re.findall(r"[;|&()<>\n]+|[^\s;|&()<>]+", cmd)


def is_op(tok):
    return bool(tok) and all(c in "();<>|&\n" for c in tok)


def segments(tokens):
    """Divide em comandos simples; descarta redirecionamentos (`2>&1`, `> arquivo`)."""
    seg, out, skip = [], [], False
    for tok in tokens:
        if skip:
            skip = False
            continue
        if is_op(tok):
            if "<" in tok or ">" in tok:
                if seg and seg[-1].isdigit():
                    seg.pop()
                skip = True
            else:
                out.append(seg)
                seg = []
        else:
            seg.append(tok)
    out.append(seg)
    return [s for s in out if s]


def git_out(directory, *args):
    try:
        r = subprocess.run(["git", "-C", directory, *args], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def protected_branches(directory):
    names = set(PROTECTED)
    top = git_out(directory, "rev-parse", "--show-toplevel") if directory else ""
    if top:
        try:
            with open(os.path.join(top, "factory", "config.sh"), encoding="utf-8") as f:
                m = re.search(r'(?m)^FACTORY_BASE_BRANCH=["\']?([^"\'\s#]+)', f.read())
            if m:
                names.add(m.group(1))
        except OSError:
            pass
    return names


def current_branch(directory):
    if not directory or not os.path.isdir(directory):
        return ""
    return git_out(directory, "symbolic-ref", "-q", "--short", "HEAD")


def branch_of(ref):
    for prefix in ("refs/heads/", "heads/"):
        if ref.startswith(prefix):
            return ref[len(prefix):]
    return ref


def check_push(args, directory):
    """Devolve o motivo do bloqueio, ou None se o push pode seguir."""
    positional, i = [], 0
    while i < len(args):
        a = args[i]
        i += 1
        if a == "--":
            positional += args[i:]
            break
        if a.startswith("--"):
            name = a.split("=", 1)[0]
            if name in FORCE_OPTS:
                return "force push não é permitido (%s)." % name
            if name in BULK_OPTS:
                return "%s publicaria também a branch base; faça push só da branch do job." % name
            if name in PUSH_VALUE_OPTS and "=" not in a:
                i += 1
        elif a.startswith("-") and len(a) > 1:
            if "f" in a[1:]:
                return "force push não é permitido (%s)." % a
            if a == "-o":
                i += 1
        else:
            positional.append(a)

    protected = protected_branches(directory)
    refspecs = positional[1:]
    if not refspecs:
        cur = current_branch(directory)
        if not cur:
            return ("não deu para descobrir qual branch este push publica; "
                    "use `git push origin <branch-do-job>`.")
        if cur in protected:
            return "push na branch `%s` não é permitido; a base só muda por MR." % cur
        return None
    for spec in refspecs:
        if spec.startswith("+"):
            return "force push não é permitido (refspec `%s`)." % spec
        dst = spec.split(":", 1)[1] if ":" in spec else spec
        if dst in ("HEAD", "@"):
            dst = current_branch(directory)
            if not dst:
                return ("não deu para descobrir qual branch `%s` publica; "
                        "use `git push origin <branch-do-job>`." % spec)
        dst = branch_of(dst)
        if dst in protected:
            return "push na branch `%s` não é permitido; a base só muda por MR." % dst
    return None


def check_command(cmd, directory, depth=0):
    for seg in segments(tokenize(cmd)):
        words = [w.strip("`") for w in seg]
        while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):  # VAR=valor git ...
            words.pop(0)
        if not words:
            continue
        head = os.path.basename(words[0])
        if head == "cd" and len(words) > 1:  # `cd <dir> && git push`
            target = os.path.expanduser(words[1])
            directory = target if os.path.isabs(target) else os.path.join(directory or "", target)
            continue
        if depth < 3 and (head == "eval" or (head in SHELLS and "-c" in words)):
            inner = words[1:] if head == "eval" else words[words.index("-c") + 1:][:1]
            for text in inner:
                reason = check_command(text, directory, depth + 1)
                if reason:
                    return reason
            continue
        for at, word in enumerate(words):
            if os.path.basename(word) != "git":
                continue
            where, j = directory, at + 1
            while j < len(words) and words[j].startswith("-"):
                opt = words[j]
                if opt in GIT_VALUE_OPTS:
                    if opt == "-C" and j + 1 < len(words):
                        target = os.path.expanduser(words[j + 1])
                        where = target if os.path.isabs(target) else os.path.join(where or "", target)
                    j += 1
                j += 1
            if j < len(words) and words[j] == "push":
                reason = check_push(words[j + 1:], where)
                if reason:
                    return reason
    return None


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return 0
    if not isinstance(event, dict):
        return 0
    tool_input = event.get("tool_input")
    cmd = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    cwd = event.get("cwd", "")
    if not isinstance(cmd, str) or "push" not in cmd:
        return 0
    reason = check_command(cmd, cwd if isinstance(cwd, str) else "")
    if reason:
        print(reason)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
