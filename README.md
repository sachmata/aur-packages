# aur-packages

Personal AUR package customizations, one directory per package.

## Packages

| Package | Vendored from | AUR commit | Version |
| --- | --- | --- | --- |
| [spotify](spotify/) | https://aur.archlinux.org/spotify.git | `0af779c` | 1:1.2.96.518-2 |

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
