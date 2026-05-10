#!/bin/bash

echo "[+] Phase 2: Starte Cloud-Backup (Restic) lokal vom NAS..."

# Prozess-Bereinigung
pkill -9 -f "restic" 2>/dev/null
sleep 2

CLOUD_DEST="rclone:gdrive:backups/homeserver_restic_repo"
HDD_DEST="/mnt/HDD-01/backups/homeserver"
RESTIC_PASS="/root/.restic_pass"
RCLONE_CONF="serve restic --stdio --tpslimit 8 --tpslimit-burst 8"

upload_daily() {
    local source_system=$1
    local hdd_path="$HDD_DEST/$source_system"

    echo "============================================================"
    echo "Processing: $source_system"

    local latest_hdd
    latest_hdd=$(ls -1 "$hdd_path" | grep -E '^[0-9]+$' | sort -n | tail -1)

    if [[ -z "$latest_hdd" ]]; then
        echo "[FEHLER] Keine Snapshots auf HDD gefunden!"
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
        echo "--> Sync erfolgreich."
    else
        echo "--> [FEHLER] Restic fehlgeschlagen!"
        return
    fi

    restic -o rclone.args="$RCLONE_CONF" -r "$CLOUD_DEST" --password-file "$RESTIC_PASS" \
        forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 1 --prune --tag "$source_system"
}

upload_daily "root"
upload_daily "home"

echo "[+] Versetze HDD in den Standby..."
hdparm -y /dev/sda
