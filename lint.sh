#!/bin/bash

set -euo pipefail

echo "warning: lint.sh is deprecated. Use 'swift package --allow-writing-to-package-directory format --lint' or 'swift package --allow-writing-to-package-directory format'."

if [[ "${1:-}" == "fix" ]]; then
  shift
  exec swift package --allow-writing-to-package-directory format "$@"
else
  exec swift package --allow-writing-to-package-directory format --lint "$@"
fi
