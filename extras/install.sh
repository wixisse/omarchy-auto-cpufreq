#!/usr/bin/env bash
# Auto CPU Freq — one-shot installer for the auto-cpufreq backend.
#
# Installs the auto-cpufreq package, enables its systemd service, and installs
# the privileged helper the bar widget uses to change governor/turbo overrides.
# Safe to re-run. Needs an interactive sudo prompt (run it in a terminal).
#
#   bash extras/install.sh
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SELF_DIR/.." && pwd)

say() { printf '\033[1;36m::\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; exit 1; }

# --- conflict awareness ----------------------------------------------------
if systemctl is-active --quiet tlp.service 2>/dev/null; then
  warn "TLP is active. auto-cpufreq and TLP both manage CPU power and should"
  warn "not run at the same time. Consider: sudo systemctl disable --now tlp"
  warn "Continuing in 5s — press Ctrl-C to abort."
  sleep 5
fi

if systemctl is-active --quiet power-profiles-daemon.service 2>/dev/null; then
  warn "power-profiles-daemon is active; auto-cpufreq wants it stopped/masked."
fi

# --- package ---------------------------------------------------------------
if command -v auto-cpufreq >/dev/null 2>&1; then
  say "auto-cpufreq is already installed"
else
  say "Installing auto-cpufreq"
  if pacman -Si auto-cpufreq >/dev/null 2>&1; then
    sudo pacman -S --noconfirm auto-cpufreq || die "pacman failed"
  elif command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm auto-cpufreq || die "yay failed"
  elif command -v paru >/dev/null 2>&1; then
    paru -S --noconfirm auto-cpufreq || die "paru failed"
  else
    die "auto-cpufreq not in the repos and no AUR helper found"
  fi
fi

command -v auto-cpufreq >/dev/null 2>&1 || die "auto-cpufreq still not on PATH"

# --- service ---------------------------------------------------------------
say "Enabling auto-cpufreq.service"
sudo systemctl enable --now auto-cpufreq.service || warn "could not enable auto-cpufreq.service"

# --- privileged helper -----------------------------------------------------
say "Installing the privileged helper"
sudo bash "$PLUGIN_DIR/extras/install-privilege.sh" || warn "privileged helper install failed"

say "Done. Open the bar widget's menu to switch modes."
printf 'auto-cpufreq: %s\n' "$(pacman -Q auto-cpufreq 2>/dev/null || echo '?')"
