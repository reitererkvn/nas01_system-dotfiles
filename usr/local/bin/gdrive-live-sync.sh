#!/bin/bash
WATCH_LIST="/root/.config/rclone/inotify-watch.txt"
EXCLUDE_FILE="/root/.config/rclone/exclude-list.txt"
CLOUD_REMOTE="gdrive:"
CLOUD_BASE="backups/live/nas-01"

# --- NEU: PFADE EINLESEN ---
VALID_PATHS=()
if [[ -f "$WATCH_LIST" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        clean_path=$(echo "$line" | sed 's/#.*//' | xargs)
        if [[ -n "$clean_path" ]]; then
            VALID_PATHS+=("$clean_path")
        fi
    done < "$WATCH_LIST"
else
    echo "[Fehler] $WATCH_LIST nicht gefunden!"
    exit 1
fi

if [ ${#VALID_PATHS[@]} -eq 0 ]; then
    echo "[Fehler] Keine gültigen Pfade in $WATCH_LIST gefunden."
    exit 1
fi

# RCLONE BASE COMMAND
RCLONE_OPTS=("-l" "--fast-list" "--bwlimit" "15M" "--exclude-from" "$EXCLUDE_FILE")

# --- PHASE 1: INITIALER SYNC ---
echo "[System] Baseline-Sync startet..."
for p in "${VALID_PATHS[@]}"; do
    if [ ! -e "$p" ]; then
        echo "[Warnung] Pfad existiert nicht: $p"
        continue
    fi
    
    # Zielpfad normalisieren: /home/kevin/Bilder -> backups/live/home/kevin/Bilder
    # Wir entfernen den führenden Slash für rclone Ziel-Konventionen
    DEST_PATH="${CLOUD_BASE}${p}"
    
    echo "[Sync] Initialisiere: $p -> ${CLOUD_REMOTE}${DEST_PATH}"
    if [ -d "$p" ]; then
        rclone sync "$p" "${CLOUD_REMOTE}${DEST_PATH}" "${RCLONE_OPTS[@]}"
    else
        # Für Dateien: kopiere in den Zielordner
        rclone copy "$p" "${CLOUD_REMOTE}${DEST_PATH%/*}" "${RCLONE_OPTS[@]}"
    fi
done
echo "[System] Baseline-Sync abgeschlossen."

# --- PHASE 2: ECHTZEIT ---
echo "[System] Inotify-Überwachung aktiv..."
inotifywait -m -r -q -e modify,create,delete,move --format "%w%f" "${VALID_PATHS[@]}" | \
while read -r FULL_EVENT_PATH; do
    # Skip temporary or excluded files early if possible (optional)
    [[ "$FULL_EVENT_PATH" == *".git"* ]] && continue
    
    echo "[Event] Änderung an: $FULL_EVENT_PATH"

    # Debounce
    sleep 2

    DEST_PATH="${CLOUD_BASE}${FULL_EVENT_PATH}"

    if [ -f "$FULL_EVENT_PATH" ]; then
        rclone copy "$FULL_EVENT_PATH" "${CLOUD_REMOTE}${DEST_PATH%/*}" "${RCLONE_OPTS[@]}"
    elif [ -d "$FULL_EVENT_PATH" ]; then
        rclone sync "$FULL_EVENT_PATH" "${CLOUD_REMOTE}${DEST_PATH}" "${RCLONE_OPTS[@]}"
    fi
done


