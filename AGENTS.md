# AGENTS.md

Personal Arch packages, each vendored from the AUR into its own directory and then reviewed and hardened. `README.md` has the procedures (checking, updating, building, adding); this file covers the rules behind them.

## Layout

- `<package>/`: `PKGBUILD`, `.SRCINFO`, helper files, and `keys/pgp/<FINGERPRINT>.asc` for upstream signing keys.
- `lib/packages.bash`: per-package `upstream_<pkgname>` (prints the latest upstream `[epoch:]pkgver`) and `update_<pkgname> <version>` (edits `./PKGBUILD`).
- `check-updates`, `update-package`: drivers around `lib/packages.bash`.
- Build output and downloaded sources stay untracked: list each package's downloads in `.gitignore` under a comment naming the package.

## Trust model

The AUR maintainer's pinned checksums are not a source of truth; several packages are bumped by bots. Every package must verify its download against what upstream itself publishes:

- When upstream signs its release metadata, verify it at build time: download the metadata and its detached signature as sources (`<name>` plus `<name>.sig`), set `validpgpkeys`, vendor the key under `keys/pgp/`, and check in `prepare()` that the payload matches the signed metadata, failing the build on a mismatch. See `claude-code` (signed manifest), `claude-desktop` and `spotify` (signed apt `Release` → `Packages` → `.deb`).
- Before trusting a new signing key, confirm its fingerprint against upstream's documentation.
- When upstream only publishes checksums (`docker-credential-secretservice-bin`), take the pinned values from that file.
- Release metadata changes with every upstream release, so its checksum entries are `SKIP`; the signature covers it. Never run `updpkgsums` or `makepkg -g` on these packages: they replace the `SKIP` entries with fixed hashes. Use `./update-package`, which takes checksums from upstream's metadata.

### Own packages (not from the AUR)

Packages of the owner's own projects (`gpvpn`) build from the project's git repository over ssh (it may be private). Release tags are unsigned, so pin the tag's commit in `_commit`, use `#commit=${_commit}`, and in `prepare()` force-fetch the tag from `origin` (makepkg's plain fetch keeps a stale tag in a reused `src/`) and fail if it no longer resolves to `_commit`. `update_<pkgname>` resolves the commit with `git ls-remote` (the peeled `^{}` line for annotated tags), and `upstream_<pkgname>` only accepts `v<digits>[.<digits>]...` tags. If the project compiles anything, run `make clean` in `build()`: `src/` is reused across builds (`gpvpn` compiles nothing since 0.7.0, so it has no `build()`). The README row says `own: <url>` with `—` as the AUR commit; the commit message body starts `Own package, not vendored from the AUR: built from <url> at tag v<version>.` in place of the `Vendored from` line.

## Reviewing a package (when adding or rebasing on a newer AUR version)

- Read every file, including the upstream payload's install scripts (e.g. a `.deb`'s `control.tar.*`): anything they set up that the PKGBUILD drops needs a decision.
- Check runtime dependencies against the binaries (`readelf -d <file> | grep NEEDED`, then `pacman -Qo` on the libraries), not only the AUR's `depends`.
- Use `${CARCH}` in `package()`, never `${arch}`, which always expands to the first architecture.
- Version-name cached downloads (`LICENSE-${pkgver}`), so makepkg's source cache cannot reuse a stale file.
- Question setuid files and other privileged bits; drop what Arch doesn't need, with a comment saying when it would be needed.
- Check whether a newer upstream version exists and what it changes.
- Download and unpack upstream payloads in a scratch directory, outside the repository.

## Verifying a change

```sh
cd <package>
makepkg --printsrcinfo > .SRCINFO   # after every PKGBUILD change
makepkg -f                          # must pass signature and prepare() checks
namcap PKGBUILD *.pkg.tar.zst
```

`namcap` warnings about prebuilt upstream binaries (no PIE or full RELRO, unstripped, files in `/opt`) can't be fixed by repackaging; note them, don't chase them. To test `update-package` changes, run it with `--no-build` in a scratch copy of the repository with packages set to an older version and zeroed checksums; the result should match the real files.

`makepkg` checks signatures against the user's GPG keyring, so a new upstream key must be imported once (`gpg --import <package>/keys/pgp/<FINGERPRINT>.asc`).

## Installing and system changes

Installing (`paru -Syu`, `paru -S`) and editing `/etc/pacman.conf` need sudo with a password, so the user runs those commands; give them the exact command. Packages are installed through paru, which builds them into the local pacman repository `sachmata-local` (listed above `cachyos`, which also has `claude-code` and `claude-desktop`) and takes updates from this git repository's pushed `.SRCINFO`; the README has the setup. Don't install with `makepkg -si`, which bypasses the local repository, and don't suggest `IgnorePkg`, which would block paru's upgrades.

## Conventions

- Keep each PKGBUILD's existing indentation (tabs in `claude-code`, 2 spaces in `claude-desktop`, 4 in the others) and its maintainer header unchanged.
- Comment non-obvious PKGBUILD choices where they are made, saying why.
- Adding a package also means: a row in the README table (AUR URL, the AUR commit and version it was based on), `upstream_`/`update_` functions in `lib/packages.bash`, and `.gitignore` entries.
- Commit messages:
  - Adding: `Add <package> <version>`, then a body starting `Vendored from <AUR URL> at <commit> (<AUR version>), with these changes:` and a bullet list of every change from the AUR version, with the reason.
  - Updating: `Update <package> to <version>-<pkgrel>`.
