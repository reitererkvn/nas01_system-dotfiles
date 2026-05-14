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
LOCKFILE="/var/lock/nas_cloud_sync.$MODE.lock"
exec 200>$LOCKFILE
if ! flock -n 200; then
    echo "[!] Ein anderes Cloud-Backup für $MODE läuft bereits. Warte auf Freigabe..."
    flock 200
fi

echo "[+] Starte Cloud-Backup (Restic) für: $MODE"

# --- Secret Acquisition (Unified /run/vault Path) ---
RESTIC_PASS="/run/vault/restic_pass"
SESSION_FILE="/run/vault/bw_session"

if [[ -f "$SESSION_FILE" ]]; then
    export BW_SESSION=$(cat "$SESSION_FILE")
    # Retrieve password from vault if not already in RAM-disk
    if [[ ! -f "$RESTIC_PASS" ]]; then
        bw get password "Restic-Backup-Key" > "$RESTIC_PASS"
        chmod 600 "$RESTIC_PASS"
    fi
else
    echo "[FEHLER] Tresor ist gesperrt. Bitte 'vault-unlock.sh' ausführen!"
    exit 1
fi

RESTIC_CACHE="/root/.cache/restic"
mkdir -p "$RESTIC_CACHE"

# SRE-Fix: Optimized for new Google Drive Limits (24k QPM)
RCLONE_CONF="serve restic --stdio --tpslimit 200 --tpslimit-burst 250 --drive-chunk-size 64M"

# --- Stale Lock Management ---
echo "[+] Prüfe auf verwaiste Restic-Locks..."
restic -o rclone.args="$RCLONE_CONF" \
    -r "$CLOUD_DEST" \
    --password-file "$RESTIC_PASS" \
    --cache-dir "$RESTIC_CACHE" \
    unlock || echo "[!] Lock-Bereigigung nicht möglich oder nicht nötig."

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

    echo "--> [Restic] Starte Block-Abgleich..."
    (
        cd "$snap_dir" || exit 1
        restic -o rclone.args="$RCLONE_CONF" \
            -o rclone.connections=16 \
            -r "$CLOUD_DEST" \
            --password-file "$RESTIC_PASS" \
            --cache-dir "$RESTIC_CACHE" \
            backup . \
            --compression auto \
            --pack-size 128 \
            --group-by host,tags \
            --tag "$source_system"
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

# --- HDD Standby Logic ---
echo "[+] Backup-Vorgänge für $MODE abgeschlossen."
sudo /sbin/hdparm -y /dev/disk/by-id/ata-TOSHIBA_DT01ACA100_16IWN23MS

flock -u 200
