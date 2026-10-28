#!/usr/bin/env bash
set -euo pipefail
if ! command -v cygpath >/dev/null; then
  echo 'Windows の Git Bash で実行してください。' >&2
  exit 1
fi
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$script_dir/setup-copilot-key.ps1")"
