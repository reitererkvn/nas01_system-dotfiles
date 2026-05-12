#!/bin/bash
# nas_cloud_sync.sh
# Lädt die Snapshots von der HDD in die Cloud (Restic).
# SRE Optimized: Balanced for 110Mbit Uplink & Google Drive API Limits.

MODE=$1 # 'homeserver' oder 'nas'

if [[ "$MODE" == "homeserver" ]]; then
    CLOUD_DEST="rclone:gdrive:backups/homeserver_restic_repo"
    HDD_DEST="/mnt/HDD-01/backups/homeserver"
    SYSTEMS=("root" "home")
elif [[ "$MODE" == "nas" ]]; then
    CLOUD_DEST="rclone:gdrive:backups/nas_restic_repo"
    HDD_DEST="/mnt/HDD-01/backups/nas"
    SYSTEMS=("root" "home" "immich" "immich-data")
else
    echo "Usage: $0 [homeserver|nas]"
    exit 1
fi

# --- Global Lock (Avoid Parallel API Pressure) ---
LOCKFILE="/var/lock/nas_cloud_sync.lock"
exec 200>$LOCKFILE
if ! flock -n 200; then
    echo "[!] Ein anderes Cloud-Backup läuft bereits. Warte auf Freigabe..."
    flock 200
fi

echo "[+] Starte Cloud-Backup (Restic) für: $MODE"

RESTIC_PASS="/root/.restic_pass"
RESTIC_CACHE="/root/.cache/restic"
mkdir -p "$RESTIC_CACHE"

# SRE-Fix: Optimized for new Google Drive Limits (24k QPM)
RCLONE_CONF="serve restic --stdio --tpslimit 16 --tpslimit-burst 20 --drive-chunk-size 64M"

# --- Stale Lock Management ---
# Checks for existing locks and unlocks if they are stale.
# This avoids manual intervention after crashed backup runs.
echo "[+] Prüfe auf verwaiste Restic-Locks..."
restic -o rclone.args="$RCLONE_CONF" \
    -r "$CLOUD_DEST" \
    --password-file "$RESTIC_PASS" \
    --cache-dir "$RESTIC_CACHE" \
    unlock || echo "[!] Lock-Bereinigung nicht möglich oder nicht nötig."

upload_daily() {
    local source_system=$1
    local hdd_path="$HDD_DEST/$source_system"

    if [[ "$source_system" == "immich-data" ]]; then
        hdd_path="/mnt/HDD-01/immich/.snapshots"
    fi

    echo "============================================================"
    echo "Processing Subvolume: $source_system"

    local latest_hdd
    latest_hdd=$(ls -1 "$hdd_path" 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -1)

    if [[ -z "$latest_hdd" ]]; then
        echo "[FEHLER] Keine Snapshots für $source_system auf HDD gefunden!"
        return
    fi

    local snap_dir="$hdd_path/$latest_hdd"
    echo "[+] Quell-Subvolume: $source_system (Snapshot ID: $latest_hdd)"

    local dir_size_mb
    dir_size_mb=$(du -sm "$snap_dir" | awk '{print $1}')

    if [[ "$dir_size_mb" -lt 1 ]]; then
        echo "--> [FEHLER] Sicherheitsabbruch! Ziel-Ordner ist physikalisch zu klein ($dir_size_mb MB)."
        return
    fi

    echo "--> [Restic] Starte Block-Abgleich..."
    # SRE-Fix: Utilizing 24k QPM Quota
    # Restic on this NAS lacks --as-path. Using 'cd' and '.' instead.
    (
        cd "$snap_dir" || exit 1
        if restic -o rclone.args="$RCLONE_CONF" \
            -o rclone.connections=4 \
            -r "$CLOUD_DEST" \
            --password-file "$RESTIC_PASS" \
            --cache-dir "$RESTIC_CACHE" \
            backup . \
            --compression auto \
            --pack-size 128 \
            --group-by host,tags \
            --tag "$source_system"; then
            echo "--> Sync für $source_system erfolgreich."
        else
            echo "--> [FEHLER] Restic für $source_system fehlgeschlagen!"
            exit 1
        fi
    ) || return

    # Retention Policy
    echo "--> [Restic] Bereinige alte Snapshots (Retention Policy) ..."
    restic -o rclone.args="$RCLONE_CONF" \
        -r "$CLOUD_DEST" \
        --password-file "$RESTIC_PASS" \
        --cache-dir "$RESTIC_CACHE" \
        forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 1 --prune --tag "$source_system"
}

for sys in "${SYSTEMS[@]}"; do
    upload_daily "$sys"
done

# --- Integrity Check (Weekly SRE Practice) ---
if [[ $(date +%u) == 7 ]]; then
    echo "============================================================"
    echo "[+] Sonntag erkannt: Starte wöchentlichen Integritätscheck (1GB Subset)..."
    restic -o rclone.args="$RCLONE_CONF" \
        -r "$CLOUD_DEST" \
        --password-file "$RESTIC_PASS" \
        --cache-dir "$RESTIC_CACHE" \
        check --read-data-subset=1G
fi

# --- Concurrency-Safe HDD Standby ---
echo "[+] Backup-Vorgänge für $MODE abgeschlossen. Prüfe auf parallele Syncs..."

OTHER_MODE="nas"
[[ "$MODE" == "nas" ]] && OTHER_MODE="homeserver"

# Fix: Use safer pgrep/grep logic
if pgrep -f "nas_cloud_sync.sh $OTHER_MODE" > /dev/null; then
    echo "--> [INFO] $OTHER_MODE-Sync läuft noch im Hintergrund. HDD bleibt aktiv."
else
    echo "[+] Kein weiterer Sync aktiv. Versetze HDD (/dev/sda) in den Standby-Modus..."
    sudo hdparm -y /dev/sda
fi

flock -u 200
