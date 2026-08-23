#!/usr/bin/env bash
# Installs Anthropic's official Claude Desktop .deb inside the current
# (Debian/Ubuntu-family) distrobox container.
#
# Runs INSIDE the container via `distrobox enter <name> -- bash <this file>`.
# $HOME is shared with the host by distrobox, so the download cache under
# ~/.cache survives container deletion/recreation.
set -euo pipefail

APT_BASE='https://downloads.claude.ai/claude-desktop/apt/stable'
CACHE_DIR="$HOME/.cache/quick-distrobox-app/claude-desktop"

log() { echo "[claude-desktop installer] $*" >&2; }
die() { echo "[claude-desktop installer] ERROR: $*" >&2; exit 1; }

command -v dpkg >/dev/null 2>&1 || die "dpkg not found — this installer needs a Debian/Ubuntu-family container"
command -v curl >/dev/null 2>&1 || die "curl not found in container"
command -v sudo >/dev/null 2>&1 || die "sudo not found in container"

arch=$(dpkg --print-architecture)
case "$arch" in
	amd64|arm64) ;;
	*) die "unsupported architecture '$arch' (claude-desktop ships amd64/arm64 only)" ;;
esac

log "Resolving newest claude-desktop for $arch from $APT_BASE ..."
index_url="$APT_BASE/dists/stable/main/binary-${arch}/Packages"
packages=$(curl -fsSL --max-time 30 "$index_url") || die "failed to fetch $index_url"

resolved=$(awk -v RS='' '
	$0 ~ /^Package: claude-desktop\n/ {
		v = f = s = ""
		n = split($0, lines, "\n")
		for (i = 1; i <= n; i++) {
			if (lines[i] ~ /^Version: /)  v = substr(lines[i], 10)
			else if (lines[i] ~ /^Filename: /) f = substr(lines[i], 11)
			else if (lines[i] ~ /^SHA256: /)   s = substr(lines[i], 9)
		}
		if (v != "" && f != "" && s != "")
			printf "%s\t%s\t%s\n", v, f, s
	}' <<< "$packages" | sort -V -k1,1 | tail -1)

[[ -n $resolved ]] || die "could not find a claude-desktop entry in $index_url"
IFS=$'\t' read -r version filename sha256 <<< "$resolved"
log "Latest available: claude-desktop $version ($filename)"

mkdir -p "$CACHE_DIR"
deb_path="$CACHE_DIR/$(basename "$filename")"

verify() {
	echo "$sha256  $deb_path" | sha256sum -c - >/dev/null 2>&1
}

if [[ -f $deb_path ]] && verify; then
	log "Using cached, checksum-verified package at $deb_path"
else
	log "Downloading $filename (this can take a while on first install) ..."
	tmp="$deb_path.part"
	curl -fSL --max-time 600 -o "$tmp" "$APT_BASE/$filename" || die "download failed"
	mv "$tmp" "$deb_path"
	verify || die "SHA256 mismatch on downloaded package — refusing to install"
	log "Download verified."
fi

log "Installing via apt (resolves dependencies from the container's own repos) ..."
sudo apt-get update -qq
sudo apt-get install -y "$deb_path"

if [[ ! -x /usr/bin/claude-desktop ]]; then
	# Upstream layout changed if this triggers; fall back to whatever apt
	# actually put on PATH rather than failing silently.
	alt=$(dpkg -L claude-desktop 2>/dev/null | grep -E '/(usr/bin|usr/local/bin)/' | head -1 || true)
	if [[ -n $alt && -x $alt ]]; then
		log "Note: binary landed at $alt, not /usr/bin/claude-desktop — update the app config's BIN if this persists."
	else
		die "apt install reported success but no claude-desktop executable was found"
	fi
fi

log "claude-desktop $version installed."
