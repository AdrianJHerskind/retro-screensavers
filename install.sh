#!/bin/bash
# Installs the Retro Screensavers from the latest GitHub release into ~/Library/Screen Savers.
#
#   curl -fsSL https://raw.githubusercontent.com/AdrianJHerskind/retro-screensavers/main/install.sh | bash
#
# Only some savers:  ... | bash -s -- Pipes FlowerBox
# Uninstall:         ... | bash -s -- --uninstall
# Don't open System Settings afterwards: add --no-open
#
# Files downloaded with curl aren't quarantined, so macOS doesn't block the savers even though
# they aren't notarized. Nothing is installed outside your own Library, and sudo isn't needed.
set -euo pipefail

REPO="AdrianJHerskind/retro-screensavers"
BUNDLE_ID_PREFIX="io.github.adrianjherskind."
INSTALL_DIR="${INSTALL_DIR:-$HOME/Library/Screen Savers}"
# For testing: where to read the release from (e.g. a file:// URL to a saved API response).
RELEASE_API="${RELEASE_API:-https://api.github.com/repos/$REPO/releases/latest}"

uninstall=false
open_settings=true
wanted=()
for argument in "$@"; do
    case "$argument" in
        --uninstall) uninstall=true ;;
        --no-open) open_settings=false ;;
        *) wanted+=("$argument") ;;
    esac
done

# Quit the screen saver host, so it loads the new versions, and reopen System Settings on the
# Screen Saver page, so the list includes them.
refresh() {
    killall legacyScreenSaver 2>/dev/null || true
    if $open_settings; then
        if pgrep -x "System Settings" >/dev/null; then
            osascript -e 'quit app "System Settings"' >/dev/null 2>&1 || true
            sleep 1
        fi
        open "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension" 2>/dev/null || true
    fi
}

if $uninstall; then
    removed=0
    for saver in "$INSTALL_DIR"/*.saver; do
        [ -d "$saver" ] || continue
        identifier=$(plutil -extract CFBundleIdentifier raw "$saver/Contents/Info.plist" 2>/dev/null || true)
        if [[ "$identifier" == "$BUNDLE_ID_PREFIX"* ]]; then
            rm -rf "$saver"
            echo "Removed $(basename "$saver" .saver)"
            removed=$((removed + 1))
        fi
    done
    open_settings=false
    refresh
    echo "Uninstalled $removed screen saver(s)."
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Finding the latest release…"
release=$(curl -fsSL "$RELEASE_API")
tag=$(grep -o '"tag_name": *"[^"]*"' <<<"$release" | head -1 | sed -E 's/.*"([^"]*)"$/\1/')
urls=$(grep -o '"browser_download_url": *"[^"]*\.zip"' <<<"$release" | sed -E 's/.*"([^"]*)"$/\1/')
# Prefer the all-in-one zip; older releases only have one zip per saver.
all_in_one=$(grep '/RetroScreensavers\.zip$' <<<"$urls" || true)
if [ -n "$all_in_one" ]; then
    urls=$all_in_one
fi
if [ -z "$urls" ]; then
    echo "Couldn't find any downloads in the latest release." >&2
    exit 1
fi

mkdir -p "$work/unpacked"
for url in $urls; do
    echo "Downloading $(basename "$url")…"
    curl -fsSL "$url" -o "$work/download.zip"
    ditto -x -k "$work/download.zip" "$work/unpacked"
done

mkdir -p "$INSTALL_DIR"
installed=0
while IFS= read -r saver; do
    name=$(basename "$saver" .saver)
    if [ ${#wanted[@]} -gt 0 ]; then
        match=false
        for choice in "${wanted[@]}"; do
            if [ "$name" = "$choice" ] || [ "$name" = "Retro$choice" ]; then
                match=true
            fi
        done
        $match || continue
    fi
    rm -rf "$INSTALL_DIR/$name.saver"
    ditto "$saver" "$INSTALL_DIR/$name.saver"
    title=$(plutil -extract CFBundleDisplayName raw "$saver/Contents/Info.plist" 2>/dev/null || echo "$name")
    version=$(plutil -extract CFBundleShortVersionString raw "$saver/Contents/Info.plist" 2>/dev/null || echo "")
    echo "Installed $title $version"
    installed=$((installed + 1))
done < <(find "$work/unpacked" -maxdepth 2 -name '*.saver' -type d | sort)

if [ "$installed" -eq 0 ]; then
    echo "Nothing installed: no saver matched ${wanted[*]+${wanted[*]}}." >&2
    exit 1
fi

refresh
echo
echo "Installed $installed screen saver(s) from $tag."
echo "Pick one in System Settings → Screen Saver; they're listed under Other, at the bottom."
