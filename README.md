# aur-packages

Personal AUR package customizations, one directory per package.

## Packages

| Package | Vendored from | AUR commit | Version |
| --- | --- | --- | --- |
| [spotify](spotify/) | https://aur.archlinux.org/spotify.git | `0af779c` | 1:1.2.96.518-2 |
| [docker-credential-secretservice-bin](docker-credential-secretservice-bin/) | https://aur.archlinux.org/docker-credential-secretservice-bin.git | `a8ab347` | 0.9.9-1 |
| [claude-code](claude-code/) | https://aur.archlinux.org/claude-code.git | `9a43483` | 2.1.296-1 |
| [claude-desktop](claude-desktop/) | https://aur.archlinux.org/claude-desktop.git | `20669f6` | 2.31226.1-1 |

## Checking for updates

```sh
./check-updates            # all packages
./check-updates <package>  # selected packages
```

Compares each package's `pkgver` with the latest upstream release. It exits 1 when an update is available and 2 when an upstream check failed.

## Updating a package

```sh
./update-package <package>             # to the latest upstream release
./update-package <package> <version>   # to a specific version
./update-package --no-build <package>  # edit only, skip the build
cd <package> && makepkg -si
git commit -am 'Update <package> to <version>-1' && git push
```

`update-package` sets `pkgver`, resets `pkgrel` to 1, pins the new checksums from upstream's published metadata (Anthropic's signed release manifest and apt index, Spotify's signed apt index, the GitHub release's `checksums.txt`), regenerates `.SRCINFO` and builds the package, which verifies upstream's signatures. If an edit fails, `PKGBUILD` and `.SRCINFO` are restored.

Don't use `updpkgsums` on packages with `SKIP` entries for repository metadata: it replaces them with fixed hashes that break the build once upstream publishes a new release.

The per-package logic lives in `lib/packages.bash`: an `upstream_<pkgname>` function that prints the latest version, used by both scripts, and an `update_<pkgname>` function that updates the `PKGBUILD`.

## Building

```sh
cd <package>
makepkg -si
```

Some of these packages also exist in a sync repository (e.g. `claude-code` and `claude-desktop` in `cachyos`), and `pacman -Syu` would replace the local build with the repository one. List every package from this repository in `IgnorePkg` in `/etc/pacman.conf`:

```ini
[options]
IgnorePkg   = spotify docker-credential-secretservice-bin claude-code claude-desktop
```

`pacman -Syu` then reports `warning: <package>: ignoring package upgrade` instead of replacing it, and `makepkg -si` asks `Install anyway?` before installing an ignored package; answer yes. Add new packages to this line when adding them below.

## Adding a package

Copy the package files from the AUR, without its git history:

```sh
git clone https://aur.archlinux.org/<package>.git /tmp/<package>
git -C /tmp/<package> log -1 --format=%h   # record in the table above
rm -rf /tmp/<package>/.git
cp -r /tmp/<package> <package>
```

Add a row to the table above with the AUR source, the commit and the version it was based on, `upstream_<pkgname>` and `update_<pkgname>` functions to `lib/packages.bash`, and the package to `IgnorePkg`.
