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
    # SRE-Fix: Check if interactive to avoid hanging on non-tty SSH
    if [ -t 0 ]; then
        read -p "Continue? (Y/n): " confirm
        [[ "$confirm" != "Y" && "$confirm" != "y" && "$confirm" != "" ]] && exit 1
    else
        echo "Non-interactive shell detected, proceeding with sync..."
    fi
fi

# ==========================================
# PHASE 1: Topologische Replikation
# ==========================================
find "$SRC" -mindepth 1 -name ".git" -prune -o -type d -printf '%P\n' | while read -r relative_dir; do
    target_dir="$DEST/$relative_dir"
    if [ ! -d "$target_dir" ]; then
        echo "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi
done

# ==========================================
# PHASE 2: I/O-Mapping (Ignoriert .git, README, LICENSE, GEMINI.md, .editorconfig)
# ==========================================
find "$SRC" -mindepth 1 \( -name ".git" -o -name "README.md" -o -name "LICENSE" -o -name "GEMINI.md" -o -name ".editorconfig" \) -prune -o -type f -printf '%P\n' | while read -r relative_file; do
    source_file="$SRC/$relative_file"
    target_file="$DEST/$relative_file"
    cp -p "$source_file" "$target_file"
    echo "Synced: $relative_file -> $target_file"
done

echo "Done! system-dotfiles written to root!"
