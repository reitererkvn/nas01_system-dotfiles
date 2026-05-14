#!/bin/bash
# vault-unlock.sh
# Unlocks the Bitwarden vault and stores the session in RAM for automated services.

# Security: Use a RAM-disk path that is only accessible to the current user
SESSION_FILE="/run/user/$(id -u)/bw_session"

echo "[Vault] Unlocking Bitwarden Vault..."

# Get the raw session key
BW_SESSION_TMP=$(bw unlock --raw)

if [ $? -eq 0 ] && [ -n "$BW_SESSION_TMP" ]; then
    echo "$BW_SESSION_TMP" > "$SESSION_FILE"
    chmod 600 "$SESSION_FILE"
    echo "[Erfolg] Tresor entsperrt. Session gespeichert in $SESSION_FILE"
    echo "[Info] Automatisierte Dienste können nun auf Secrets zugreifen."
else
    echo "[Fehler] Entsperren fehlgeschlagen. Bitte Passwort prüfen."
    exit 1
fi
