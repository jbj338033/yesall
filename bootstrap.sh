#!/bin/sh
set -eu

repo=${YESALL_REPO:-jbj338033/yesall}
ref=${YESALL_REF:-main}
action=${1:-install}
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/yesall-bootstrap.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

archive="$tmp_dir/yesall.tar.gz"
curl -fsSL "https://github.com/$repo/archive/refs/heads/$ref.tar.gz" -o "$archive"
tar -xzf "$archive" -C "$tmp_dir"
repo_dir=$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)

case $action in
    install)
        exec "$repo_dir/install.sh"
        ;;
    uninstall)
        exec "$repo_dir/uninstall.sh"
        ;;
    *)
        printf 'Usage: bootstrap.sh [install|uninstall]\n' >&2
        exit 2
        ;;
esac
