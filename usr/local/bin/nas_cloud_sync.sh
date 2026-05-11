#!/bin/bash
# nas_cloud_sync.sh
# Lädt die Snapshots von der HDD in die Cloud (Restic).
# SRE Optimized: Fixed API Overload and added Concurrency-Safety for HDD Standby.

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

echo "[+] Starte Cloud-Backup (Restic) für: $MODE"

RESTIC_PASS="/root/.restic_pass"

# SRE-Fix: Reduzierung der API-Calls durch Begrenzung der Transaktionen
# --tpslimit 5 schützt vor Google Drive 403/500 Fehlern bei zu vielen Metadaten-Updates
# --drive-chunk-size 64M reduziert HTTP-Requests beim Upload großer Packs
RCLONE_CONF="serve restic --stdio --tpslimit 5 --tpslimit-burst 5 --drive-chunk-size 64M"

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
        echo "--> [FEHLER] Sicherheitsabbruch! Ziel-Ordner ist physikalisch zu klein ($dir_size_mb MB)."
        return
    fi

    echo "--> [Restic] Starte Block-Abgleich (SRE Mode: --pack-size 128) ..."
    # SRE-Fix: --pack-size 128 bündelt Daten in größere Pakete -> massiv weniger API-Calls
    # -o rclone.connections=4 verhindert, dass zu viele parallele Uploads die API blockieren
    if restic -o rclone.args="$RCLONE_CONF" \
        -o rclone.connections=4 \
        -r "$CLOUD_DEST" \
        --password-file "$RESTIC_PASS" \
        backup "$snap_dir" \
        --pack-size 128 \
        --group-by host,tags \
        --tag "$source_system"; then
        echo "--> Sync für $source_system erfolgreich."
    else
        echo "--> [FEHLER] Restic für $source_system fehlgeschlagen!"
        return
    fi

    # Retention Policy
    echo "--> [Restic] Bereinige alte Snapshots (Retention Policy) ..."
    restic -o rclone.args="$RCLONE_CONF" \
        -r "$CLOUD_DEST" \
        --password-file "$RESTIC_PASS" \
        forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --keep-yearly 1 --prune --tag "$source_system"
}

for sys in "${SYSTEMS[@]}"; do
    upload_daily "$sys"
done

# --- Concurrency-Safe HDD Standby ---
echo "[+] Backup-Vorgänge für $MODE abgeschlossen. Prüfe auf parallele Syncs..."

# Finde heraus, welcher Modus NICHT gerade läuft
OTHER_MODE="nas"
[[ "$MODE" == "nas" ]] && OTHER_MODE="homeserver"

# Prüfe, ob die andere Instanz von nas_cloud_sync.sh noch aktiv ist
# Wir filtern nach der Shell und dem Parameter, schließen aber unsere eigene PID aus.
if pgrep -f "nas_cloud_sync.sh $OTHER_MODE" | grep -v $$ > /dev/null; then
    echo "--> [INFO] $OTHER_MODE-Sync läuft noch im Hintergrund. HDD bleibt aktiv."
else
    echo "[+] Kein weiterer Sync aktiv. Versetze HDD (/dev/sda) in den Standby-Modus..."
    sudo hdparm -y /dev/sda
fi
