#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash build-vencord.sh
bash build-helper.sh
bash build-patch.sh
