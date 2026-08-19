#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/yesall-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
fake_bin=$test_dir/fake-bin
mkdir -p "$fake_bin"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

field() {
    key=$1
    file=$2
    sed -n "s/^# yesall:$key=//p" "$file"
}

fake_command=$test_dir/fake-command
cat >"$fake_command" <<'FAKE'
#!/bin/sh
printf 'binary=%s\n' "${0##*/}"
for arg in "$@"; do
    printf 'arg=%s\n' "$arg"
done
printf 'env:OPENCODE_CONFIG_CONTENT=%s\n' "${OPENCODE_CONFIG_CONTENT-}"
printf 'env:GOOSE_MODE=%s\n' "${GOOSE_MODE-}"
exit "${YESALL_FAKE_EXIT:-0}"
FAKE
chmod 755 "$fake_command"

for provider in "$repo_dir"/providers/*; do
    sh -n "$provider"
    binary=$(field binary "$provider")
    [ -e "$fake_bin/$binary" ] || ln -s "$fake_command" "$fake_bin/$binary"
done
sh -n "$repo_dir/bin/yesall"
sh -n "$repo_dir/install.sh"
sh -n "$repo_dir/uninstall.sh"

for provider in "$repo_dir"/providers/*; do
    binary=$(field binary "$provider")
    prefix=$(field prefix "$provider")
    env_value=$(field env "$provider")
    actual=$(PATH="$fake_bin:$PATH" "$provider" 'two words' '*' '--flag=value')

    expected=$(
        printf 'binary=%s\n' "$binary"
        set -f
        old_ifs=$IFS
        IFS=' '
        # Provider prefixes are controlled, space-delimited argv metadata.
        # shellcheck disable=SC2086
        set -- $prefix
        IFS=$old_ifs
        for arg in "$@"; do
            [ -n "$arg" ] && printf 'arg=%s\n' "$arg"
        done
        printf 'arg=two words\narg=*\narg=--flag=value\n'
        opencode_value=
        goose_value=
        if [ "${env_value#OPENCODE_CONFIG_CONTENT=}" != "$env_value" ]; then
            opencode_value=${env_value#*=}
        fi
        if [ "${env_value#GOOSE_MODE=}" != "$env_value" ]; then
            goose_value=${env_value#*=}
        fi
        printf 'env:OPENCODE_CONFIG_CONTENT=%s\n' "$opencode_value"
        printf 'env:GOOSE_MODE=%s\n' "$goose_value"
    )

    [ "$actual" = "$expected" ] || fail "argument or environment forwarding: ${provider##*/}"
done

set +e
PATH="$fake_bin:$PATH" YESALL_FAKE_EXIT=37 "$repo_dir/providers/cld" >/dev/null
exit_status=$?
set -e
[ "$exit_status" -eq 37 ] || fail 'exit status forwarding'

install_bin=$test_dir/install-bin
YESALL_BIN_DIR="$install_bin" "$repo_dir/install.sh" >/dev/null
YESALL_BIN_DIR="$install_bin" "$repo_dir/install.sh" >/dev/null
[ -x "$install_bin/yesall" ] || fail 'control command installation'
[ -x "$install_bin/cld" ] || fail 'provider installation'
PATH="$fake_bin:$install_bin:$PATH" "$install_bin/yesall" doctor >/dev/null
"$install_bin/yesall" list | grep 'Claude Code' >/dev/null || fail 'provider discovery'

YESALL_BIN_DIR="$install_bin" "$repo_dir/uninstall.sh" >/dev/null
[ ! -e "$install_bin/yesall" ] || fail 'control command removal'
[ ! -e "$install_bin/cld" ] || fail 'provider removal'

collision_bin=$test_dir/collision-bin
mkdir -p "$collision_bin"
printf 'user file\n' >"$collision_bin/cld"
set +e
YESALL_BIN_DIR="$collision_bin" "$repo_dir/install.sh" >/dev/null 2>&1
collision_status=$?
set -e
[ "$collision_status" -ne 0 ] || fail 'collision status'
[ "$(cat "$collision_bin/cld")" = 'user file' ] || fail 'collision preservation'
[ -x "$collision_bin/cdx" ] || fail 'partial installation after collision'
YESALL_BIN_DIR="$collision_bin" "$repo_dir/uninstall.sh" >/dev/null
[ "$(cat "$collision_bin/cld")" = 'user file' ] || fail 'uninstall preservation'
[ ! -e "$collision_bin/cdx" ] || fail 'managed collision-set removal'

printf 'PASS: yesall\n'
