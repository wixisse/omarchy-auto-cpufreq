#!/usr/bin/env bash
# Auto CPU Freq — one-shot installer for the auto-cpufreq backend.
#
# Installs the auto-cpufreq daemon (and retires power-profiles-daemon) via
# extras/install-daemon.sh, then installs the privileged helper the bar widget
# uses to change governor/turbo overrides. Safe to re-run. Needs an interactive
# sudo prompt (run it in a terminal).
#
#   bash extras/install.sh
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SELF_DIR/.." && pwd)

say() { printf '\033[1;36m::\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }

# --- daemon ----------------------------------------------------------------
say "Installing the auto-cpufreq daemon"
bash "$SELF_DIR/install-daemon.sh" || exit 1

# --- privileged helper -----------------------------------------------------
say "Installing the privileged helper"
sudo bash "$PLUGIN_DIR/extras/install-privilege.sh" || warn "privileged helper install failed"

say "Done. Open the bar widget's menu to switch modes."
