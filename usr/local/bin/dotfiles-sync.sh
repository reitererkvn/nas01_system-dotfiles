#!/usr/bin/env bash

SRC="/opt/system-dotfiles"
DEST="/"
DEST="${DEST%/}"  # removes "/" at end

if [ "$EUID" -ne 0 ]; then
  echo "Fatal: System-Sync erfordert Kernel-Root-Privilegien."
  exit 1
fi

# Verifikation of I/O-source
if [ ! -d "$SRC" ]; then
    echo "Error: Source-File $SRC missing."
    exit 1
fi

# askes if sure to copy to root
if [ "$DEST" == "" ] || [ "$DEST" == "/" ]; then
    echo "!!!WARNING!!! Files contained in $SRC will be overwritten in /"
    read -p "Continue? (Y/n): " confirm
    [[ "$confirm" != "Y" && "$confirm" != "y" && "$confirm" != "" ]] && exit 1
fi

# ==========================================
# PHASE 1: Topologische Replikation
# ==========================================
# using %P to only get subfolder relative to $SRC
find "$SRC" -mindepth 1 -name ".git" -prune -o -type d -printf '%P\n' | while read -r relative_dir; do
    target_dir="$DEST/$relative_dir"
    if [ ! -d "$target_dir" ]; then
        echo "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi
done

# ==========================================
# PHASE 2: I/O-Mapping (Kopieren statt Verlinken, Ignoriert .git, README.md, LIECENSE, .editorconfig)
# ==========================================
find "$SRC" -mindepth 1 \( -name ".git" -o -name "REAME.md" -o -name "LICENSE" -o -name ".editorconfig" \) -prune -o -type f -printf '%P\n' | while read -r relative_file; do
    source_file="$SRC/$relative_file"
    target_file="$DEST/$relative_file"

    # Kopiere Datei
    # -p = bewahrt Berechtigungen (wichtig für /etc)
    cp -p "$source_file" "$target_file"
    echo "Synced: $relative_file -> $target_file"
done

echo "Done! system-dotfiles written to root!"
