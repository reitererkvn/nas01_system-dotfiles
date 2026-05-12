#!/bin/bash
# immich-sre.sh
# Manages Immich stack with dynamic secrets from Vaultwarden.

ACTION=$1 # 'up', 'down', 'restart'

# --- Secret Injection ---
source /root/.vaultwarden

# Unlock vault
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
    bw sync > /dev/null
export DB_PASSWORD=$(bw get password Immich-db)

if [[ -z "$DB_PASSWORD" ]]; then
    echo "[FEHLER] Konnte Immich-DB Passwort nicht aus Vaultwarden abrufen!"
    exit 1
fi

cd /opt/containerd/immich

case "$ACTION" in
    up)
        sudo -E docker compose up -d
        ;;
    down)
        sudo docker compose down
        ;;
    restart)
        sudo -E docker compose restart
        ;;
    *)
        echo "Usage: $0 [up|down|restart]"
        exit 1
        ;;
esac
