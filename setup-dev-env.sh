#!/bin/bash
# Обратная совместимость: ./setup-dev-env.sh → bin/setup-dev-env
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PHPDEV_ROOT="$ROOT"

# shellcheck source=lib/load.sh
source "$ROOT/lib/load.sh"

main "$@"
