#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bin_dir=${YESALL_BIN_DIR:-"${XDG_BIN_HOME:-$HOME/.local/bin}"}
marker='# yesall:managed'
removed=0

remove_one() {
    source_file=$1
    name=${source_file##*/}
    target=$bin_dir/$name

    [ -e "$target" ] || [ -L "$target" ] || return
    if [ -f "$target" ] && [ ! -L "$target" ] && [ "$(sed -n '2p' "$target")" = "$marker" ]; then
        rm -f "$target"
        removed=$((removed + 1))
    else
        printf 'yesall: preserving unmanaged %s\n' "$target" >&2
    fi
}

remove_one "$repo_dir/bin/yesall"
for provider in "$repo_dir"/providers/*; do
    [ -f "$provider" ] || continue
    remove_one "$provider"
done

printf 'yesall: removed %s commands from %s\n' "$removed" "$bin_dir"
