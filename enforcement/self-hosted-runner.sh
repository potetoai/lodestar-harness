#!/usr/bin/env bash
# Run a private repo's CI on this machine when GitHub's free Actions minutes
# run out (jobs "not started ... spending limit"). Guide: setup-guide.md,
# "Optional: run CI on this machine".
# Run inside Linux or WSL (not Git Bash): one runner per repo under
# ~/actions-runner/<repo>, a service that starts with the machine, and the
# repo variable LODESTAR_RUNNER=self-hosted that ci.yml reads.
#   bash self-hosted-runner.sh <owner/repo>...        register, start, switch CI
#   bash self-hosted-runner.sh --off <owner/repo>...  CI back to GitHub's runner
# Refuses a public repo: a fork PR would run its code on this machine.
set -euo pipefail
die() { echo "self-hosted-runner: $1" >&2; exit 1; }
off=0; [ "${1-}" = --off ] && { off=1; shift; }
[ $# -gt 0 ] || die "usage: self-hosted-runner.sh [--off] <owner/repo>..."
# WSL: the Linux gh may not be logged in; the Windows one usually is.
GH=gh
if ! gh auth status >/dev/null 2>&1; then
  w="/mnt/c/Program Files/GitHub CLI/gh.exe"
  [ -x "$w" ] && "$w" auth status >/dev/null 2>&1 && GH=$w ||
    die "gh is not logged in (run: gh auth login)."
fi
ghq() { "$GH" "$@" | tr -d '\r'; }
if [ $off = 1 ]; then
  for r in "$@"; do ghq variable delete LODESTAR_RUNNER -R "$r" && echo "$r: CI back on GitHub's runner."; done
  exit 0
fi
[ "$(uname -s)" = Linux ] || die "run this inside Linux or WSL."
missing=""
for t in git make curl jq tar; do command -v $t >/dev/null || missing="$missing $t"; done
[ -z "$missing" ] || die "install first: sudo apt install -y$missing build-essential"
for r in "$@"; do
  [ "$(ghq repo view "$r" --json visibility -q .visibility)" = PRIVATE ] ||
    die "$r is not private; never run a public repo's CI on this machine."
done
ver=$(ghq api repos/actions/runner/releases/latest -q .tag_name); ver=${ver#v}
case $(uname -m) in x86_64) arch=x64 ;; aarch64) arch=arm64 ;; *) die "unknown CPU $(uname -m)" ;; esac
tgz="$HOME/actions-runner-linux-$arch-$ver.tar.gz"
[ -f "$tgz" ] || curl -fsSL -o "$tgz" \
  "https://github.com/actions/runner/releases/download/v$ver/actions-runner-linux-$arch-$ver.tar.gz"
sudo -v   # the password once, for the services
for r in "$@"; do
  name=${r#*/}; d="$HOME/actions-runner/$name"
  if [ -f "$d/.runner" ]; then echo "== $r: runner already set up"; else
    echo "== $r: registering"
    mkdir -p "$d" && tar xzf "$tgz" -C "$d"
    tok=$(ghq api -X POST "repos/$r/actions/runners/registration-token" -q .token)
    (cd "$d" && ./config.sh --unattended --url "https://github.com/$r" --token "$tok" \
      --name "$(hostname)-$name" --replace)
    (cd "$d" && { sudo ./bin/installdependencies.sh >/dev/null || true; } &&
      sudo ./svc.sh install "$USER" && sudo ./svc.sh start)
  fi
  ghq variable set LODESTAR_RUNNER --body self-hosted -R "$r"
done
# WSL stops when no Windows program holds it, and the runners go offline:
# a hidden "sleep infinity" started at each Windows logon keeps it up.
if [ -n "${WSL_DISTRO_NAME-}" ] && command -v wslpath >/dev/null; then
  appdata=$(wslpath "$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')")
  vbs="$appdata/Microsoft/Windows/Start Menu/Programs/Startup/lodestar-wsl-$WSL_DISTRO_NAME.vbs"
  printf '%s\r\n' "CreateObject(\"WScript.Shell\").Run \"wsl.exe -d $WSL_DISTRO_NAME --exec sleep infinity\", 0, False" >"$vbs"
  pgrep -f "^sleep infinity" >/dev/null || (cd /mnt/c && cmd.exe /c start "" wscript.exe "$(wslpath -w "$vbs")") || true
  echo "WSL is kept running at each Windows logon ($vbs)."
fi
echo "Runners:"
for r in "$@"; do ghq api "repos/$r/actions/runners" -q '.runners[]|.name+" "+.status'; done
