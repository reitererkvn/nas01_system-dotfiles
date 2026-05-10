#!/bin/bash
# nas_local_snapshot_sync.sh
# Spiegelt lokale SSD-Snapshots auf die HDD für lokale Redundanz.

DEST_BASE="/mnt/HDD-01/backups/nas"

sync_local() {
    local src_dir=$1
    local dst_dir=$2
    local last_snap=""

    # Erstelle Zielstruktur falls nötig
    sudo mkdir -p "$dst_dir"

    # Sortiere Snapshots numerisch (Snapper Struktur)
    # Nutze find um Fehler bei leeren Verzeichnissen zu vermeiden
    for snap in $(sudo find "$src_dir" -maxdepth 1 -name "[0-9]*" | sort -V); do
        id=$(basename "$snap")
        snap_path="$snap/snapshot"

        if [ ! -d "$dst_dir/$id" ]; then
            echo "--> Lokale Spiegelung ID $id nach $dst_dir..."
            
            # Finde den letzten bereits gesicherten Snapshot für inkrementelles Senden
            last_id=$(ls -1 "$dst_dir" | grep -E '^[0-9]+$' | sort -n | tail -1)
            
            if [ -z "$last_id" ]; then
                echo "    (Initialer Snapshot - Full Send)"
                sudo btrfs send "$snap_path" | sudo btrfs receive "$dst_dir/"
            else
                last_snap="$dst_dir/$last_id"
                echo "    (Inkrementell gegen ID $last_id)"
                sudo btrfs send -p "$last_snap" "$snap_path" | sudo btrfs receive "$dst_dir/"
            fi
            
            # Snapper-Struktur flachklopfen für einfachere Restic-Sicherung
            sudo mv "$dst_dir/snapshot" "$dst_dir/$id"
        fi
    done
}

echo "[+] Starte lokalen Snapshot-Sync (SSD -> HDD)..."
sync_local "/.snapshots" "$DEST_BASE/root"
sync_local "/home/.snapshots" "$DEST_BASE/home"
sync_local "/opt/containerd/immich/.snapshots" "$DEST_BASE/immich"

echo "[+] Erzeuge Snapper-Snapshot für Immich-Archiv auf HDD..."
sudo snapper -c immich-hdd create --description "Nightly Archive Backup"

echo "[+] Lokaler Sync abgeschlossen. Erstelle Trigger-Datei für Cloud-Backup..."
sudo touch "$DEST_BASE/.sync_done"
