#!/usr/bin/env bash
# Auto CPU Freq — install the privileged helper used to set auto-cpufreq
# overrides (governor / turbo) from the bar.
#
# Run once, as root:
#   sudo bash extras/install-privilege.sh
# Remove it again with:
#   sudo bash extras/install-privilege.sh --uninstall
#
# It copies bin/autocpufreq-priv to /usr/local/bin/autocpufreq-priv and adds a
# sudoers drop-in that lets the invoking user run exactly that helper without a
# password. The helper only accepts a fixed set of keywords, so the drop-in does
# not grant a general-purpose root shell.
set -euo pipefail

HELPER=/usr/local/bin/autocpufreq-priv
SUDOERS=/etc/sudoers.d/autocpufreq
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_HELPER="$SELF_DIR/../bin/autocpufreq-priv"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "install-privilege.sh: must run as root (try: sudo bash $0)" >&2
  exit 1
fi

if [[ ${1:-} == "--uninstall" ]]; then
  rm -f "$SUDOERS" "$HELPER"
  echo "Removed $SUDOERS and $HELPER"
  exit 0
fi

[[ -f $SRC_HELPER ]] || { echo "install-privilege.sh: $SRC_HELPER not found" >&2; exit 1; }

install -o root -g root -m 0755 "$SRC_HELPER" "$HELPER"

target_user=${SUDO_USER:-${USER:-}}
[[ -n $target_user && $target_user != root ]] || {
  echo "install-privilege.sh: cannot determine the desktop user; set SUDO_USER" >&2
  exit 1
}

tmp=$(mktemp)
printf '%s ALL=(root) NOPASSWD: %s force *, %s turbo *\n' \
  "$target_user" "$HELPER" "$HELPER" >"$tmp"
chmod 0440 "$tmp"
visudo -cf "$tmp" >/dev/null
install -o root -g root -m 0440 "$tmp" "$SUDOERS"
rm -f "$tmp"

echo "Installed $HELPER and $SUDOERS for user '$target_user'."
