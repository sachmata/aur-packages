# Per-package upstream knowledge, sourced by check-updates and update-package.
#
# For each package directory <pkgname>:
#   upstream_<pkgname>          prints the latest upstream version as [epoch:]pkgver
#   update_<pkgname> <version>  edits ./PKGBUILD to that version, taking the
#                               pinned checksums from upstream's published
#                               metadata (signed where upstream signs it)

fetch() { curl -fsSL --retry 2 --max-time 60 "$@"; }

die() { echo "error: $*" >&2; return 1; }

# Prints [epoch:]pkgver from a package directory's .SRCINFO
local_version() {
  awk -F' = ' '
    $1 ~ /^\tepoch$/  { epoch = $2 }
    $1 ~ /^\tpkgver$/ { ver = $2 }
    END { print (epoch ? epoch ":" : "") ver }
  ' "$1/.SRCINFO"
}

# Highest Version: in a Debian Packages index read from stdin
apt_latest_version() { awk '/^Version:/ { print $2 }' | sort -V | tail -n1; }

# Prints <field> of the entry whose Version: matches the awk regex <version_re>,
# from a Debian Packages index read from stdin
apt_field() {
  # The regex goes through the environment: awk -v would process its escapes
  VERSION_RE="^Version: ${1}\$" awk -v field="$2" '
    BEGIN { RS = ""; FS = "\n"; re = ENVIRON["VERSION_RE"] }
    {
      matched = 0; value = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ re) matched = 1
        if (index($i, field ": ") == 1) value = substr($i, length(field) + 3)
      }
      if (matched) { print value; exit }
    }
  '
}

# Escapes the ERE metacharacters of a fixed string (e.g. the + in 4.0.3+p7)
ere_escape() { sed 's/[][\\.*^$+?(){}|]/\\&/g' <<<"$1"; }

# set_var NAME VALUE: rewrite NAME=VALUE in ./PKGBUILD, keeping its quoting
set_var() {
  local name=$1 value=$2
  grep -qE "^${name}=" PKGBUILD || die "${name}= not found in PKGBUILD" || return
  sed -i -E "s/^(${name}=)(['\"]?)[^'\"]*(['\"]?)\$/\1\2${value}\3/" PKGBUILD
  grep -qE "^${name}=['\"]?$(ere_escape "$value")['\"]?\$" PKGBUILD || die "failed to set ${name}"
}

# set_sum ARRAY HASH: replace the first checksum of ARRAY in ./PKGBUILD, which
# must sit on the same line as the opening "ARRAY=("
set_sum() {
  local array=$1 sum=$2
  [[ $sum =~ ^[0-9a-f]{64}([0-9a-f]{64})?$ ]] || die "invalid checksum for ${array}: '${sum}'" || return
  grep -qE "^${array}=\('[0-9a-f]+'" PKGBUILD || die "${array}=('<checksum>' not found in PKGBUILD" || return
  sed -i -E "s/^(${array}=\(')[0-9a-f]+'/\1${sum}'/" PKGBUILD
  grep -qE "^${array}=\('${sum}'" PKGBUILD || die "failed to set ${array}"
}

# set_sum_at ARRAY INDEX HASH: replace the INDEX-th (0-based) checksum of ARRAY
# in ./PKGBUILD, where the array lists one quoted checksum per line
set_sum_at() {
  local array=$1 index=$2 sum=$3 tmp
  [[ $sum =~ ^[0-9a-f]{64}([0-9a-f]{64})?$ ]] || die "invalid checksum for ${array}[${index}]: '${sum}'" || return
  tmp=$(awk -v array="$array" -v index_="$index" -v sum="$sum" '
    index($0, array "=(") == 1 { inarray = 1; n = 0 }
    inarray && match($0, /'"'"'[0-9a-f]+'"'"'/) {
      if (n == index_) { $0 = substr($0, 1, RSTART) sum substr($0, RSTART + RLENGTH - 1); done = 1 }
      n++
    }
    inarray && /\)/ { inarray = 0 }
    { print }
    END { exit !done }
  ' PKGBUILD) || die "${array}[${index}] checksum not found in PKGBUILD" || return
  printf '%s\n' "$tmp" > PKGBUILD
}

# --- claude-code --------------------------------------------------------------

_claude_code_releases=https://downloads.claude.ai/claude-code-releases

upstream_claude-code() {
  fetch "${_claude_code_releases}/latest"
}

update_claude-code() {
  local ver=$1 manifest
  # Signed by Anthropic; makepkg verifies the signature and prepare() rechecks
  # the binary against it at build time
  manifest=$(fetch "${_claude_code_releases}/${ver}/manifest.json") || return
  [[ $(jq -r .version <<<"$manifest") == "$ver" ]] || die "manifest is not for ${ver}" || return

  set_var pkgver "$ver" &&
    set_sum sha256sums_x86_64 "$(jq -r '.platforms["linux-x64"].checksum' <<<"$manifest")" &&
    set_sum sha256sums_aarch64 "$(jq -r '.platforms["linux-arm64"].checksum' <<<"$manifest")"
}

# --- claude-desktop -----------------------------------------------------------

_claude_desktop_dists=https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable

upstream_claude-desktop() {
  fetch "${_claude_desktop_dists}/main/binary-amd64/Packages" | apt_latest_version
}

update_claude-desktop() {
  local ver=$1 re amd64 arm64
  re=${ver//./\\.}
  # Listed in the Packages indexes covered by the signed Release file;
  # makepkg and prepare() verify that chain at build time
  amd64=$(fetch "${_claude_desktop_dists}/main/binary-amd64/Packages" | apt_field "$re" SHA256) || return
  arm64=$(fetch "${_claude_desktop_dists}/main/binary-arm64/Packages" | apt_field "$re" SHA256) || return

  set_var pkgver "$ver" &&
    set_sum sha256sums_x86_64 "$amd64" &&
    set_sum sha256sums_aarch64 "$arm64"
}

# --- docker-credential-secretservice-bin --------------------------------------

_docker_credential_repo=docker/docker-credential-helpers

upstream_docker-credential-secretservice-bin() {
  fetch "https://api.github.com/repos/${_docker_credential_repo}/releases/latest" |
    jq -er '.tag_name | ltrimstr("v")'
}

update_docker-credential-secretservice-bin() {
  local ver=$1 checksums license amd64 arm64
  # Upstream publishes checksums.txt with each release, but signs nothing
  checksums=$(fetch "https://github.com/${_docker_credential_repo}/releases/download/v${ver}/checksums.txt") || return
  amd64=$(awk -v f="*docker-credential-secretservice-v${ver}.linux-amd64" '$2 == f { print $1 }' <<<"$checksums")
  arm64=$(awk -v f="*docker-credential-secretservice-v${ver}.linux-arm64" '$2 == f { print $1 }' <<<"$checksums")
  license=$(fetch "https://raw.githubusercontent.com/${_docker_credential_repo}/v${ver}/LICENSE" | sha256sum | cut -d' ' -f1) || return

  set_var pkgver "$ver" &&
    set_sum sha256sums "$license" &&
    set_sum sha256sums_x86_64 "$amd64" &&
    set_sum sha256sums_aarch64 "$arm64"
}

# --- spotify ------------------------------------------------------------------

_spotify_packages=https://repository.spotify.com/dists/testing/non-free/binary-amd64/Packages

upstream_spotify() {
  # Debian version 1:1.3.4.258.gc60b10b0946a -> 1:1.3.4.258 (the commit is _commit)
  fetch "$_spotify_packages" | apt_latest_version | sed -E 's/\.g[0-9a-f]+$//'
}

update_spotify() {
  local ver=$1 epoch pkgver packages debver sum
  epoch=${ver%%:*}
  pkgver=${ver#*:}
  [[ $ver == *:* ]] || die "spotify version needs an epoch, e.g. 1:${ver}" || return

  # Listed in the Packages index covered by the signed Release file;
  # makepkg and prepare() verify that chain at build time
  packages=$(fetch "$_spotify_packages") || return
  debver=$(apt_field "${epoch}:${pkgver//./\\.}\\.g[0-9a-f]+" Version <<<"$packages")
  [[ -n $debver ]] || die "spotify ${ver} not found in the repository" || return
  sum=$(apt_field "${debver//./\\.}" SHA512 <<<"$packages")

  set_var pkgver "$pkgver" &&
    set_var epoch "$epoch" &&
    set_var _commit "${debver##*.}" &&
    set_sum sha512sums "$sum"
}

# --- gpvpn --------------------------------------------------------------------

# Own private repository (https://github.com/sachmata/gpvpn), read over ssh
_gpvpn_repo=git@github.com:sachmata/gpvpn.git

upstream_gpvpn() {
  # Release tags only (v1.2.3): not other v-prefixed names or pre-releases,
  # which sort -V would rank above the release and pacman can't take as pkgver
  git ls-remote --tags --refs "$_gpvpn_repo" |
    sed -nE 's|.*\trefs/tags/v([0-9]+(\.[0-9]+)*)$|\1|p' | sort -V | tail -n1
}

update_gpvpn() {
  local ver=$1 refs commit
  # Tags are unsigned, so pin the commit the tag points to; prepare() checks
  # the tag still matches at build time. An annotated tag's commit is its
  # peeled ^{} line; a lightweight tag has only the plain line.
  refs=$(git ls-remote "$_gpvpn_repo" "refs/tags/v${ver}" "refs/tags/v${ver}^{}") || return
  commit=$(awk -v t="refs/tags/v${ver}" '
    $2 == t "^{}" { peeled = $1 }
    $2 == t       { plain = $1 }
    END           { print (peeled ? peeled : plain) }
  ' <<<"$refs")
  [[ $commit =~ ^[0-9a-f]{40}$ ]] || die "tag v${ver} not found in ${_gpvpn_repo}" || return

  set_var pkgver "$ver" &&
    set_var _commit "$commit"
}

# --- parmetis -----------------------------------------------------------------

_parmetis_sources=https://deb.debian.org/debian/dists/unstable/non-free/source/Sources.xz

# Prints the parmetis stanza of Debian unstable's non-free Sources index
# (awk reads to the end: exiting early would fail the pipe with SIGPIPE)
_parmetis_stanza() {
  fetch "$_parmetis_sources" | xz -dc |
    awk 'BEGIN { RS = ""; FS = "\n" } $1 == "Package: parmetis" && !done { print; done = 1 }'
}

upstream_parmetis() {
  # Debian version 4.0.3-7 -> 1:4.0.3+p7 (the epoch comes from the AUR package)
  local debver
  debver=$(_parmetis_stanza | sed -n 's/^Version: //p') || return
  [[ $debver =~ ^[0-9.]+-[0-9]+$ ]] || die "unexpected Debian version '${debver}'" || return
  echo "1:${debver/-/+p}"
}

update_parmetis() {
  local ver=$1 epoch pkgver debver upver stanza orig debian
  [[ $ver =~ ^([0-9]+):([0-9.]+)\+p([0-9]+)$ ]] ||
    die "parmetis version must look like 1:4.0.3+p7, not '${ver}'" || return
  epoch=${BASH_REMATCH[1]} pkgver=${BASH_REMATCH[2]}+p${BASH_REMATCH[3]}
  upver=${BASH_REMATCH[2]} debver=${BASH_REMATCH[2]}-${BASH_REMATCH[3]}

  # Listed in the Sources index covered by the signed Release file;
  # makepkg and prepare() verify that chain at build time
  stanza=$(_parmetis_stanza) || return
  grep -qx "Version: ${debver}" <<<"$stanza" ||
    die "Debian unstable provides $(sed -n 's/^Version: //p' <<<"$stanza"), not ${debver}" || return
  sha256_of() {
    awk -v file="$1" '
      /^[^ ]/ { insums = ($0 == "Checksums-Sha256:") }
      insums && $3 == file { print $1 }
    ' <<<"$stanza"
  }
  orig=$(sha256_of "parmetis_${upver}.orig.tar.gz")
  debian=$(sha256_of "parmetis_${debver}.debian.tar.xz")

  set_var pkgver "$pkgver" &&
    set_var epoch "$epoch" &&
    set_sum_at sha256sums 0 "$orig" &&
    set_sum_at sha256sums 1 "$debian"
}

# --- openfoam-org -------------------------------------------------------------

# Versions are <major>.<committer date of the master commit>+<short commit>,
# as on the AUR. Each major version is its own repository (OpenFOAM-14), whose
# master carries that release's fixes. Upstream signs nothing, so PKGBUILD pins
# the full commit and prepare() checks it is on master.
_openfoam_api=https://api.github.com/repos/OpenFOAM

upstream_openfoam-org() {
  local major commit
  major=$(local_version openfoam-org) major=${major%%.*}
  # A new major release is a new repository; this only tracks the current one
  if fetch -o /dev/null "${_openfoam_api}/OpenFOAM-$((major + 1))" 2>/dev/null; then
    echo "warning: OpenFOAM-$((major + 1)) exists; openfoam-org follows OpenFOAM-${major}" >&2
  fi
  commit=$(fetch "${_openfoam_api}/OpenFOAM-${major}/commits/master") || return
  jq -er --arg major "$major" \
    '"\($major).\(.commit.committer.date[0:10] | gsub("-"; ""))+\(.sha[0:7])"' <<<"$commit"
}

update_openfoam-org() {
  local ver=$1 major date short commit sha status
  [[ $ver =~ ^([0-9]+)\.([0-9]{8})\+([0-9a-f]{7})$ ]] ||
    die "openfoam-org version must look like 14.20261111+64cfdf5, not '${ver}'" || return
  major=${BASH_REMATCH[1]} date=${BASH_REMATCH[2]} short=${BASH_REMATCH[3]}

  commit=$(fetch "${_openfoam_api}/OpenFOAM-${major}/commits/${short}") || return
  sha=$(jq -er .sha <<<"$commit") || return
  [[ $sha == "$short"* ]] || die "commit ${short} resolved to ${sha}" || return
  [[ $(jq -r '.commit.committer.date[0:10] | gsub("-"; "")' <<<"$commit") == "$date" ]] ||
    die "commit ${short} is not from ${date}" || return
  # Only commits on master, not those reachable only from pull request refs
  status=$(fetch "${_openfoam_api}/OpenFOAM-${major}/compare/${sha}...master" | jq -r .status) || return
  [[ $status == ahead || $status == identical ]] ||
    die "commit ${sha} is not on OpenFOAM-${major}'s master (${status})" || return

  set_var pkgver "$ver" &&
    set_var _commit "$sha"
}
