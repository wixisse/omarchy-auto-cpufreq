#!/usr/bin/env bash
# Auto CPU Freq — install the auto-cpufreq daemon and hand CPU power management
# over from power-profiles-daemon.
#
# Installs the auto-cpufreq package, disables (and masks) power-profiles-daemon
# so the two do not fight over the same CPU knobs, then enables
# auto-cpufreq.service. Idempotent; needs an interactive sudo prompt.
#
#   bash extras/install-daemon.sh
set -uo pipefail

say() { printf '\033[1;36m::\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; exit 1; }

unit_exists() { systemctl cat "$1" >/dev/null 2>&1; }

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

# --- retire power-profiles-daemon ------------------------------------------
# auto-cpufreq and power-profiles-daemon both write the same CPU frequency /
# governor knobs, so exactly one of them may run. auto-cpufreq wins here.
if unit_exists power-profiles-daemon.service; then
  say "Disabling power-profiles-daemon (auto-cpufreq takes over)"
  sudo systemctl disable --now power-profiles-daemon.service \
    || warn "could not stop power-profiles-daemon.service"
  sudo systemctl mask power-profiles-daemon.service \
    || warn "could not mask power-profiles-daemon.service"
else
  say "power-profiles-daemon is not installed"
fi

# TLP also fights over the same knobs — warn, but leave it to the user.
if unit_exists tlp.service; then
  warn "TLP is installed; auto-cpufreq and TLP must not run together."
  warn "Consider: sudo systemctl disable --now tlp.service"
fi

# --- service ---------------------------------------------------------------
say "Enabling auto-cpufreq.service"
if unit_exists auto-cpufreq.service; then
  sudo systemctl enable --now auto-cpufreq.service \
    || die "could not enable auto-cpufreq.service"
else
  say "auto-cpufreq.service unit missing; running the upstream installer"
  sudo auto-cpufreq --install || die "auto-cpufreq --install failed"
fi

say "Done. auto-cpufreq: $(pacman -Q auto-cpufreq 2>/dev/null || echo '?')"
