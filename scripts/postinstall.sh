#!/bin/sh
set -e
# Keep the desktop database in sync when desktop-file-utils is present
# (harmless no-op otherwise).
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi
# Re-apply the extra-SDK patches when an additional SDK is installed: a
# fresh install or upgrade restores the pristine hvigor / hos-project-mgmt
# files. No-op without an extra SDK. Same as the pacman post_install /
# post_upgrade hook in devecostudio.install.
if [ -x /opt/devecostudio/bin/patch-extra-sdk.sh ]; then
  /opt/devecostudio/bin/patch-extra-sdk.sh --auto || true
fi

# The C++ plugin calls File#setExecutable(true) on its language server
# (/opt/devecostudio/tools/llvm/server/lsp/linux/clangd). Java implements that
# as a chmod, which fails on a root-owned file even when it is already
# executable — the IDE then reports "clangd setExecutable failed" and disables
# C/C++ support. Give the file to the user who installed the package; fall
# back to the first logged-in user when installed without sudo (tty/rootfs).
# Best-effort: on an image build no user exists yet and this is a no-op.
_chown_clangd() {
  _clangd=/opt/devecostudio/tools/llvm/server/lsp/linux/clangd
  [ -e "$_clangd" ] || return 0
  _user=${SUDO_USER:-}
  if [ -z "$_user" ] || [ "$_user" = root ]; then
    command -v loginctl >/dev/null 2>&1 || return 0
    _user=$(loginctl list-users --no-legend 2>/dev/null | awk 'NR==1 {print $2}') || _user=
  fi
  case "$_user" in
    ''|root) return 0 ;;
  esac
  id "$_user" >/dev/null 2>&1 || return 0
  chown "$_user:" "$_clangd" 2>/dev/null || true
}
_chown_clangd
