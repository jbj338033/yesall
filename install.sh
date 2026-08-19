#!/bin/sh
set -eu

bin_dir=${YESALL_BIN_DIR:-$HOME/.yesall/bin}
marker='# yesall:managed'
status=0
installed=0
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
source_dir=
tmp_dir=

if [ -f "$script_dir/bin/yesall" ] && [ -d "$script_dir/providers" ]; then
    source_dir=$script_dir
else
    raw_base=${YESALL_RAW_BASE:-https://raw.githubusercontent.com/jbj338033/yesall/main}
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/yesall-install.XXXXXX")
    trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
    source_dir=$tmp_dir/repo
    mkdir -p "$source_dir/bin" "$source_dir/providers"
    curl -fsSL "$raw_base/bin/yesall" -o "$source_dir/bin/yesall"
    curl -fsSL "$raw_base/providers/index" | while IFS= read -r shortcut; do
        [ -n "$shortcut" ] || continue
        curl -fsSL "$raw_base/providers/$shortcut" -o "$source_dir/providers/$shortcut"
    done
fi

mkdir -p "$bin_dir"

is_managed() {
    [ -f "$1" ] && [ ! -L "$1" ] && [ "$(sed -n '2p' "$1")" = "$marker" ]
}

install_one() {
    source_file=$1
    name=${source_file##*/}
    target=$bin_dir/$name

    if [ -e "$target" ] || [ -L "$target" ]; then
        if ! is_managed "$target"; then
            printf 'yesall: preserving existing %s\n' "$target" >&2
            status=1
            return
        fi
    fi

    temp_file=$(mktemp "$bin_dir/.yesall.XXXXXX")
    if ! cp "$source_file" "$temp_file" || ! chmod 755 "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi
    mv -f "$temp_file" "$target"
    installed=$((installed + 1))
}

field() {
    key=$1
    file=$2
    sed -n "s/^# yesall:$key=//p" "$file"
}

install_one "$source_dir/bin/yesall"
for provider in "$source_dir"/providers/*; do
    [ -f "$provider" ] || continue
    grep -q '^# yesall:kind=provider$' "$provider" || continue
    install_one "$provider"
done

printf 'yesall: installed %s commands in %s\n' "$installed" "$bin_dir"
printf '\nAvailable commands:\n'
for provider in "$source_dir"/providers/*; do
    [ -f "$provider" ] || continue
    grep -q '^# yesall:kind=provider$' "$provider" || continue
    name=${provider##*/}
    if is_managed "$bin_dir/$name"; then
        printf '  %-5s %s\n' "$name" "$(field name "$provider")"
    fi
done
case :${PATH:-}: in
    *:"$bin_dir":*) ;;
    *)
        printf '\nyesall: add this to your current shell:\n' >&2
        printf "  export PATH=\"\$HOME/.yesall/bin:\$PATH\"\n" >&2
        ;;
esac

exit "$status"
