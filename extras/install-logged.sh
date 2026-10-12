#!/usr/bin/env bash
# Auto CPU Freq — run extras/install.sh inside a pseudo-tty so `sudo` can prompt,
# while teeing everything to a log file that the shell (or a human) can read.
#
#   bash extras/install-logged.sh [/tmp/opencode/autocpufreq-install.log]
set -u
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG=${1:-/tmp/opencode/autocpufreq-install.log}
mkdir -p "$(dirname "$LOG")"
exec script -q -e -c "bash '$SELF_DIR/install.sh'" "$LOG"
