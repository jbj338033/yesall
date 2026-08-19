#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bin_dir=${YESALL_BIN_DIR:-"${XDG_BIN_HOME:-$HOME/.local/bin}"}
marker='# yesall:managed'
status=0
installed=0

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

install_one "$repo_dir/bin/yesall"
for provider in "$repo_dir"/providers/*; do
    [ -f "$provider" ] || continue
    install_one "$provider"
done

printf 'yesall: installed %s commands in %s\n' "$installed" "$bin_dir"
case :${PATH:-}: in
    *:"$bin_dir":*) ;;
    *)
        printf 'yesall: add %s to PATH\n' "$bin_dir" >&2
        ;;
esac

exit "$status"
