#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/module-status.sh"

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  module_status_main "$@"
fi
