#!/usr/bin/env bash
# Локальные проверки качества (bash -n, smoke CLI, опционально shellcheck)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

fail=0

ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}○${NC} $*"; }
err() { echo -e "${RED}✗${NC} $*"; fail=1; }

echo "== bash -n =="
while IFS= read -r -d '' f; do
    if bash -n "$f"; then
        ok "bash -n $f"
    else
        err "bash -n $f"
    fi
done < <(find setup-dev-env.sh bin lib scripts -type f \( -name '*.sh' -o -name 'dev' -o -name 'new-project' -o -name 'vhost' -o -name 'setup-dev-env' \) -print0 2>/dev/null)

echo ""
echo "== smoke CLI =="
if ./setup-dev-env.sh help >/dev/null; then ok "help"; else err "help"; fi
if ./setup-dev-env.sh lang help >/dev/null; then ok "lang help"; else err "lang help"; fi
if ./setup-dev-env.sh lang list >/dev/null; then ok "lang list"; else err "lang list"; fi
if ./setup-dev-env.sh db help >/dev/null; then ok "db help"; else err "db help"; fi
if ./setup-dev-env.sh db status >/dev/null; then ok "db status"; else err "db status"; fi
if ./setup-dev-env.sh db update --dry-run >/dev/null; then ok "db update --dry-run"; else err "db update --dry-run"; fi
if ./setup-dev-env.sh profile list >/dev/null; then ok "profile list"; else err "profile list"; fi

echo ""
echo "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
    # Не падаем на style warnings: фокус на ошибках (-S error) для CI-дружелюбия локально тоже можно -S warning
    sc_args=(-e SC1090 -e SC1091 -e SC2034 -e SC2155 -e SC2086 -e SC2164 -e SC2001 -e SC2012 -e SC2181)
    if shellcheck -S warning "${sc_args[@]}" setup-dev-env.sh bin/setup-dev-env lib/load.sh lib/common.sh lib/cli.sh lib/lang.sh lib/db.sh lib/profiles.sh 2>/dev/null; then
        ok "shellcheck (core)"
    else
        warn "shellcheck reported issues (core) — см. вывод ниже"
        shellcheck -S warning "${sc_args[@]}" setup-dev-env.sh bin/setup-dev-env lib/load.sh lib/common.sh lib/cli.sh lib/lang.sh lib/db.sh lib/profiles.sh || true
    fi
else
    warn "shellcheck не установлен (apt install shellcheck)"
fi

echo ""
if [ "$fail" -eq 0 ]; then
    echo -e "${GREEN}Все проверки пройдены${NC}"
    exit 0
fi
echo -e "${RED}Есть ошибки${NC}"
exit 1
