#!/bin/bash
# nas_cloud_sync.sh
# Lädt die Snapshots von der HDD in die Cloud (Restic).
# Unterstützt 'homeserver' und 'nas' als Parameter.

MODE=$1 # 'homeserver' oder 'nas'

if [[ "$MODE" == "homeserver" ]]; then
    CLOUD_DEST="rclone:gdrive:backups/homeserver_restic_repo"
    HDD_DEST="/mnt/HDD-01/backups/homeserver"
    SYSTEMS=("root" "home")
elif [[ "$MODE" == "nas" ]]; then
    CLOUD_DEST="rclone:gdrive:backups/nas_restic_repo"
    HDD_DEST="/mnt/HDD-01/backups/nas"
    SYSTEMS=("root" "home" "immich")
else
    echo "Usage: $0 [homeserver|nas]"
    exit 1
fi

echo "[+] Starte Cloud-Backup (Restic) für: $MODE"

# Prozess-Bereinigung
pkill -9 -f "restic" 2>/dev/null
sleep 2

RESTIC_PASS="/root/.restic_pass"
# TPS Limits für Google Drive API
RCLONE_CONF="serve restic --stdio --tpslimit 8 --tpslimit-burst 8"

upload_daily() {
    local source_system=$1
    local hdd_path="$HDD_DEST/$source_system"

    # Spezialfall für Immich-Daten auf der HDD (direkt in .snapshots)
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
    echo "[+] Ziel-Ordner: $snap_dir"

    local dir_size_mb
    dir_size_mb=$(du -sm "$snap_dir" | awk '{print $1}')

    if [[ "$dir_size_mb" -lt 1 ]]; then
        echo "--> [FEHLER] Sicherheitsabbruch! Ziel-Ordner ist physikalisch zu klein (${dir_size_mb} MB)."
        return
    fi

    echo "--> [Restic] Starte Block-Abgleich mit Cloud ..."
    if restic -o rclone.args="$RCLONE_CONF" \
        -r "$CLOUD_DEST" \
        --password-file "$RESTIC_PASS" \
        backup "$snap_dir" \
        --group-by host,tags \
        --tag "$source_system"; then
        echo "--> Sync für $source_system erfolgreich."
    else
        echo "--> [FEHLER] Restic für $source_system fehlgeschlagen!"
        return
    fi

    # Retention Policy
    restic -o rclone.args="$RCLONE_CONF" -r "$CLOUD_DEST" --password-file "$RESTIC_PASS" \
        forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 1 --prune --tag "$source_system"
}

for sys in "${SYSTEMS[@]}"; do
    upload_daily "$sys"
done

# HDD Standby am Ende des NAS-Backups
if [[ "$MODE" == "nas" ]]; then
    echo "[+] Alle NAS-Backups abgeschlossen. Versetze HDD in den Standby..."
    sudo hdparm -y /dev/sda
fi
