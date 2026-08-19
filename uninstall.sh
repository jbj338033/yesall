#!/bin/sh
set -eu

bin_dir=${YESALL_BIN_DIR:-$HOME/.yesall/bin}
marker='# yesall:managed'
removed=0
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
provider_dir=
tmp_dir=

if [ -d "$script_dir/providers" ]; then
    provider_dir=$script_dir/providers
else
    raw_base=${YESALL_RAW_BASE:-https://raw.githubusercontent.com/jbj338033/yesall/main}
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/yesall-uninstall.XXXXXX")
    trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
    provider_dir=$tmp_dir/providers
    mkdir -p "$provider_dir"
    curl -fsSL "$raw_base/providers/index" | while IFS= read -r shortcut; do
        [ -n "$shortcut" ] || continue
        printf '# yesall:kind=provider\n' >"$provider_dir/$shortcut"
    done
fi

remove_name() {
    name=$1
    target=$bin_dir/$name

    [ -e "$target" ] || [ -L "$target" ] || return
    if [ -f "$target" ] && [ ! -L "$target" ] && [ "$(sed -n '2p' "$target")" = "$marker" ]; then
        rm -f "$target"
        removed=$((removed + 1))
    else
        printf 'yesall: preserving unmanaged %s\n' "$target" >&2
    fi
}

remove_name yesall
for provider in "$provider_dir"/*; do
    [ -f "$provider" ] || continue
    grep -q '^# yesall:kind=provider$' "$provider" || continue
    remove_name "${provider##*/}"
done

printf 'yesall: removed %s commands from %s\n' "$removed" "$bin_dir"
