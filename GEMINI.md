# SRE Infrastructure & Dotfiles Context
**Stand:** 12. Mai 2026
**Architektur-Level:** Senior SRE / Modular Decoupled

## 1. System-Topologie (Hardware & Netz)
*   **Desktop (`homeserver`):** CachyOS Linux | i7-7700K | 16GB RAM | GTX 1070 Ti | 5K Display | IP: `192.168.178.22`
*   **NAS (`nas-01`):** Debian 13 | AMD A10-6700 | 8GB RAM | 256GB SSD + 1TB HDD (`/mnt/HDD-01`) | IP: `192.168.178.46`
*   **Connectivity:** SSH via Desktop-Agent-Forwarding; NAS -> Cloud via GDrive (SRE-Limit: 200 TPS, 16 Conn).

## 2. System-Architektur (HyprCachyOS & NAS-01)
*   **Storage (NAS-01):** Hybrid-Modell (SSD für DB/Ingest, HDD für Archiv) via `MergerFS` unter `/lib/immich`.
*   **Snapshot-Logik:** SSD-Subvolumes via Snapper. HDD-Snapshots nachts via Sync-Skript.
*   **Trigger-Logik:** Event-basierte Trigger via SSD-Files (`/var/lib/nas-sync-triggers/`) zur HDD-Schonung.
*   **Backup-Kette:** 
    *   Desktop -> NAS via `upload_snapshots.sh` (Trigger: `homeserver_sync.done`).
    *   NAS Cloud Sync via Restic (`nas_cloud_sync.sh`) nach lokalem Sync (Trigger: `nas_local_sync.done`).

## 2. Hyprland Configuration (Lua-Native)
*   **Version:** 0.55+ (Lua API).
*   **Entry Point:** `~/.config/hypr/hyprland.lua`.
*   **Module:** `colors`, `monitors`, `look`, `keybinds`, `windowrules`, `autostart`, `sun`, `layout`.
*   **Custom Layout:** `lua:master-grid` (Zentriertes Master, Grid-Seiten mit Breiten-Auffüllung).
*   **Automation:** `sun.lua` verwaltet Wallpaper-Wechsel event-basiert (ersetzt `hypr-sun.sh` und Systemd-Timer).

## 3. Workflows & Repo-Exklusivität (Source of Truth)
*   **STRIKTE TRENNUNG:** 
    *   **User-Space (`~/.dotfiles/`):** Enthält User-Konfigurationen (Zsh, Hyprland, etc.) und das Master-Ansible-Playbook für Infrastruktur-Vorbereitung.
    *   **NAS-System (`nas-01:/opt/system-dotfiles/`):** Source of Truth für NAS-Dienste (Semaphore, Caddy, Backup-Skripte).
    *   **Desktop-System (`/opt/system-dotfiles/`):** Source of Truth für Desktop-Systemd-Units und Hardware-Skripte.
*   **Secret Management:**
    *   **RAM-Vault:** Einmaliges Entsperren via `sudo vault-unlock.sh` pro Boot. Token liegt in `/run/vault/bw_session`.
    *   **Zero-Leak:** Keine Klartext-Passwörter in Git. Docker nutzt `${VAR}` in Compose-Files, gespeist aus lokalen `.env` Dateien.
*   **Repo-First:** Änderungen MÜSSEN zuerst im jeweiligen Repository erfolgen. Deployment via `dotfiles-sync.sh` (User) oder manueller Kopie (System).

## 4. Bekannte Fallstricke & Fixes
*   **Bitwarden Token:** Der Session-Token in `/run/vault/bw_session` darf keinen Zeilenumbruch enthalten (via `printf` schreiben).
*   **Ownership:** Alle Verzeichnisse unter `/opt/containerd/` werden durch Ansible auf `root:root` vereinheitlicht, um Idempotenz-Konflikte zu vermeiden.
*   **Semaphore Self-Restart:** Docker-Tasks in Semaphore nutzen den Tag `infrastructure_only`, um zu verhindern, dass Semaphore sich während des Laufs selbst absägt.

## 5. Offene Projekte
- **Paperless-ngx:** Einrichtung geplant (Pfade: SSD für DB/Ingest, HDD für Media).
- **Monitoring:** Grafana/Prometheus Stack auf NAS aktiv (Port 3001/9090 via Caddy).
- **Secret Management (In Progress):**
    *   ✅ Vaultwarden Instanz auf NAS (Port 8080 via HTTPS/Tailscale/Caddy).
    *   ✅ Bitwarden CLI Integration auf Desktop & NAS via API-Keys.
    *   ✅ Dynamische Secret-Injection für `nas_cloud_sync.sh`.
    *   ⏳ Backup von SSH-Keys (Private Keys) in den Vault.
    *   ⏳ Migration der `rclone.conf` Tokens in den Vault.
    - **Ansible Playbooks:** Automatisierung des System-Setups (Pakete, Admin-Stack, Configs) für Desktop und NAS.
    *   *Status:* Dedizierte Rollen verwalten Docker-Services (Caddy, Prometheus, Grafana, Semaphore).
    *   *Struktur:* Jeder Dienst hat ein eigenes Verzeichnis in `/opt/containerd/`.
    - **DNS-Infrastruktur:** Lokaler DNS-Server (z.B. Pi-hole/AdGuard) für herstellerunabhängige Namensauflösung (ohne Tailscale-Zwang).

- **Gemini Telegram Bot:** 
    - **Ziel:** Remote-Steuerung des Systems via Telegram.
    - **Anforderung:** Vollständige Konversations-Unterstützung.
    - **Workflow:** Session startet bei Nachricht, endet bei `/quit`. Integration als `systemd --user` Service.

## 6. Abgeschlossene Projekte
*   ✅ Hyprland Lua Migration (Mai 2026)
*   ✅ Integration intelligenter Wallpaper-Scheduler in Lua
*   ✅ SRE Secret Management Foundation (Vaultwarden & CLI Automation)
*   ✅ Zentralisierung der Dokumentations-Infrastruktur (`gemini-sync-docs.sh`)

---
*Dieses Dokument ist die primäre Instruktion für Gemini CLI Sessions in diesem Workspace.*
