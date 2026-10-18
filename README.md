# aur-packages

Personal AUR package customizations, one directory per package.

## Packages

| Package | Vendored from | AUR commit | Version |
| --- | --- | --- | --- |
| [spotify](spotify/) | https://aur.archlinux.org/spotify.git | `0af779c` | 1:1.2.96.518-2 |
| [docker-credential-secretservice-bin](docker-credential-secretservice-bin/) | https://aur.archlinux.org/docker-credential-secretservice-bin.git | `a8ab347` | 0.9.9-1 |
| [claude-code](claude-code/) | https://aur.archlinux.org/claude-code.git | `9a43483` | 2.1.296-1 |
| [claude-desktop](claude-desktop/) | https://aur.archlinux.org/claude-desktop.git | `20669f6` | 2.31226.1-1 |
| [gpvpn](gpvpn/) | own: https://github.com/sachmata/gpvpn (not on the AUR) | — | 0.4.0-1 |

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
git commit -am 'Update <package> to <version>-1' && git push
paru -Syu
```

`paru -Syu` pulls this repository, shows the diff for review, builds the new version into the local repository and installs it (see [Installing with paru](#installing-with-paru)).

`update-package` sets `pkgver`, resets `pkgrel` to 1, pins the new checksums from upstream's published metadata (Anthropic's signed release manifest and apt index, Spotify's signed apt index, the GitHub release's `checksums.txt`), regenerates `.SRCINFO` and builds the package, which verifies upstream's signatures. If an edit fails, `PKGBUILD` and `.SRCINFO` are restored.

Don't use `updpkgsums` on packages with `SKIP` entries for repository metadata: it replaces them with fixed hashes that break the build once upstream publishes a new release.

The per-package logic lives in `lib/packages.bash`: an `upstream_<pkgname>` function that prints the latest version, used by both scripts, and an `update_<pkgname>` function that updates the `PKGBUILD`.

## Building

```sh
cd <package>
makepkg -f
```

A test build only; install through paru (below), so the package lands in the local repository.

## Installing with paru

Some of these packages also exist in a sync repository (e.g. `claude-code` and `claude-desktop` in `cachyos`), and `pacman -Syu` would replace a local build with the repository one. To prevent that, paru builds this repository's packages into a local pacman repository listed above all others, and checks this git repository for their updates.

1. Create the local repository:

   ```sh
   sudo install -d -o $USER -g $USER /var/lib/repo/sachmata-local
   ```

2. In `/etc/pacman.conf`, add it **above the first other repository** (pacman takes a package from the first repository that has it):

   ```ini
   [sachmata-local]
   SigLevel = Optional TrustAll
   Server = file:///var/lib/repo/sachmata-local
   ```

3. In `~/.config/paru/paru.conf` (paru reads only this file when it exists, so copy the options from `/etc/paru.conf` too):

   ```ini
   [options]
   LocalRepo = sachmata-local

   [sachmata]
   Url = ssh://git@github.com/sachmata/aur-packages.git
   ```

   paru needs a URL with a scheme; `git@github.com:...` fails with `relative URL without a base`.

4. Install packages with `paru -Sy sachmata/<package>`; `paru -Syu` then upgrades them from this repository's pushed `.SRCINFO`, ahead of the AUR.

`paru -Qu` doesn't give the PKGBUILD repository priority: it reports AUR versions of these packages (e.g. a newer AUR `pkgrel`) and misses this repository's updates. Check with `paru -Syu`, which lists the upgrades before asking.

Don't list these packages in `IgnorePkg`: paru honours it too and would skip their upgrades.

## Adding a package

Copy the package files from the AUR, without its git history:

```sh
git clone https://aur.archlinux.org/<package>.git /tmp/<package>
git -C /tmp/<package> log -1 --format=%h   # record in the table above
rm -rf /tmp/<package>/.git
cp -r /tmp/<package> <package>
```

Add a row to the table above with the AUR source, the commit and the version it was based on, and `upstream_<pkgname>` and `update_<pkgname>` functions to `lib/packages.bash`. Once pushed, install it with `paru -Sy sachmata/<package>`.

For a package of your own project, follow "Own packages" in `AGENTS.md` instead of copying from the AUR.

`gpvpn` needs `odin` from `extra` to build: `makepkg -f` and `./update-package gpvpn` stop with "Missing dependencies: odin" until it is installed (paru installs it as a build dependency).
