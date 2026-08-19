# yesall

Short commands that launch coding-agent CLIs with the most autonomous mode each tool officially supports.

```sh
cld "fix the failing test"
cdx "review this repository"
kmi
```

These commands deliberately reduce or remove approval checks. Use them only where you are comfortable letting the underlying agent act without confirmation.

## Install

One-line install from GitHub:

```sh
curl -fsSL https://raw.githubusercontent.com/jbj338033/yesall/main/bootstrap.sh | sh
```

This is a `curl | sh` installer: it downloads the tagged repository archive to a temporary directory, then runs the repository's normal installer. Review `bootstrap.sh` before using it in a new environment.

For a checked-out install:

```sh
./install.sh
```

Commands are installed into `${XDG_BIN_HOME:-$HOME/.local/bin}`. Set `YESALL_BIN_DIR` to choose another directory:

```sh
YESALL_BIN_DIR=/usr/local/bin ./install.sh
```

The installer never overwrites an unmanaged file. Re-running it updates only files carrying the `yesall` marker.

## Commands

List every included shortcut and the command it launches:

```sh
yesall
```

Check which underlying CLIs are installed:

```sh
yesall doctor
```

The provider files are the source of truth, so `yesall list` stays current without maintaining a separate registry. Gemini CLI is intentionally not included.

## Uninstall

```sh
./uninstall.sh
```

Or from anywhere:

```sh
curl -fsSL https://raw.githubusercontent.com/jbj338033/yesall/main/bootstrap.sh | sh -s -- uninstall
```

Only files carrying the `yesall` marker are removed.

## Add a provider

Create one executable file in `providers/`. Its filename is the shortcut:

```sh
#!/bin/sh
# yesall:managed
# yesall:kind=provider
# yesall:name=Example Agent
# yesall:binary=example-agent
# yesall:prefix=--maximum-autonomy
# yesall:env=
# yesall:source=https://example.com/official-cli-reference
exec example-agent --maximum-autonomy "$@"
```

The installer, uninstaller, command listing, dependency doctor, and test suite discover it automatically.

## Test

```sh
./tests/run.sh
```
