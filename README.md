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

Compares each package's `pkgver` with the latest upstream release. It exits 1 when an update is available and 2 when an upstream check failed. A new package needs an `upstream_<pkgname>` function in the script.

## Building

```sh
cd <package>
makepkg -si
```

## Adding a package

Copy the package files from the AUR, without its git history:

```sh
git clone https://aur.archlinux.org/<package>.git /tmp/<package>
git -C /tmp/<package> log -1 --format=%h   # record in the table above
rm -rf /tmp/<package>/.git
cp -r /tmp/<package> <package>
```

Add a row to the table above with the AUR source, the commit and the version it was based on.
