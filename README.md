# quick-distrobox-app

Export GUI apps from a [distrobox](https://distrobox.it) container to your host as
ordinary commands and app-menu entries — and have them **self-heal**. If the
container gets deleted, the next time you launch the app it transparently
recreates the container, reinstalls the app, and runs it. No separate repair
step to remember.

Ships with a ready-to-use definition for **Claude Desktop**, installed from
Anthropic's own official APT repository (`downloads.claude.ai`), inside an
Ubuntu 24.04 container.

## Install

```bash
git clone https://github.com/bodencrouch/quick-distrobox-app.git
cd quick-distrobox-app
./install.sh
```

This symlinks `bin/quick-distrobox-app` to `~/.local/bin/quick-distrobox-app`.
Make sure `~/.local/bin` is on your `PATH`.

## Claude Desktop

```bash
quick-distrobox-app ensure claude-desktop
claude-desktop
```

The first `ensure` (or the first launch of `claude-desktop`, which calls
`ensure` itself) creates the `ubuntu-dev` container from `ubuntu:24.04` if it
doesn't already exist, downloads and installs Anthropic's official
`claude-desktop` `.deb` from their APT repo, and exports a `~/.local/bin/claude-desktop`
launcher plus a `.desktop` app-menu entry. Every later launch re-checks all of
that in a couple of cheap existence checks and only does real work again if
something is actually missing — e.g. because you ran
`distrobox rm -f ubuntu-dev`.

The downloaded `.deb` is cached under `~/.cache/quick-distrobox-app/`, which
lives on the host and survives container deletion, so a rebuild after
deleting the container is fast and doesn't re-download.

## Any other app

```bash
quick-distrobox-app add <name> [--container NAME] [--distro IMAGE] \
    (--apt PKG | --script PATH) [--bin PATH] [--desktop-name NAME] \
    [--comment TEXT] [--categories STR]
```

- `--container` — the distrobox container name to use (default `ubuntu-dev`).
- `--distro` — the image to create that container from **if it doesn't
  already exist** (default `ubuntu:24.04`). Any image usable with
  `distrobox create --image` works — Fedora, Arch, openSUSE, etc. Ignored if
  the container already exists.
- `--apt PKG` — install via `apt-get install -y PKG` inside the container.
- `--script PATH` — install by running this script inside the container
  instead (for anything apt can't do directly — see
  `installers/claude-desktop.sh` for an example that resolves and verifies a
  package from a vendor's own repo).
- `--bin PATH` — the installed executable's path inside the container
  (default `/usr/bin/<name>`); this is also what `ensure` checks for to
  decide whether (re)installation is needed.

`add` writes the definition to `~/.config/quick-distrobox-app/apps/<name>.conf`
and immediately runs `ensure` for it.

Examples:

```bash
quick-distrobox-app add slack --apt slack-desktop
quick-distrobox-app add my-tool --container work-dev --distro fedora:41 \
    --bin /usr/local/bin/my-tool --script ~/scripts/install-my-tool.sh
```

## Other commands

```bash
quick-distrobox-app list          # every known app + install/export status
quick-distrobox-app ensure <name> # (re)create/(re)install/(re)export one app
quick-distrobox-app ensure-all    # ensure every known app
quick-distrobox-app remove <name> # drop the host launcher + .desktop entry
quick-distrobox-app doctor        # basic environment sanity checks
```

## How self-healing works

The generated `~/.local/bin/<name>` launcher never changes — it just calls:

```
quick-distrobox-app run <name> -- "$@"
```

and `run` always calls `ensure` first. All the actual repair logic (create
container → install app → write launcher/.desktop) lives in one place in the
CLI, so it stays current for every previously-exported app without
regenerating anything. `distrobox-enter`'s own interactive "create this
container?" prompt is never relied on — `ensure` checks explicitly and calls
`distrobox create --yes`, so it also works correctly when launched from a
`.desktop` icon with no terminal attached.

## Config layout

- `~/.config/quick-distrobox-app/apps/<name>.conf` — your app definitions
  (created by `add`); these override the bundled ones in `apps.d/` of the
  same name.
- `~/.config/quick-distrobox-app/installers/` — your custom `--script`
  installers, referenced by name from a config the same way
  `installers/claude-desktop.sh` is referenced from `apps.d/claude-desktop.conf`.
- `~/.cache/quick-distrobox-app/` — download caches (installer scripts are
  expected to use this so re-installs after a container rebuild are fast).
