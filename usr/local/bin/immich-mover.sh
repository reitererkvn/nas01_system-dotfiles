#!/bin/bash
SOURCE="/opt/containerd/immich/data/"
DEST="/mnt/HDD-01/immich/"
LIMIT_KB=$((50 * 1024 * 1024)) # 50 GB

# Aktuelle Größe der SSD in KB prüfen
CURRENT_SIZE=$(du -sk "$SOURCE" | cut -f1)

if [ "$CURRENT_SIZE" -gt "$LIMIT_KB" ]; then
    echo "SSD Limit überschritten ($CURRENT_SIZE KB). Verschiebe alte Dateien..."
    
    # Finde Dateien, die älter als 7 Tage sind, und verschiebe sie
    # (Dieser Ansatz ist performanter als ständiges Nachmessen beim Verschieben)
    find "$SOURCE" -type f -mtime +7 -exec rsync -a --remove-source-files {} "$DEST" \;
    
    # Leere Ordner auf der SSD aufräumen
    find "$SOURCE" -type d -empty -delete
    echo "Verschieben abgeschlossen."
else
    echo "SSD Belegung ($CURRENT_SIZE KB) ist unter dem Limit von 50 GB. Nichts zu tun."
fi
