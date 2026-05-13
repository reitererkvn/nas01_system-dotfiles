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
*   **STRIKTE TRENNUNG:** Dieses Repo (`~/.dotfiles/`) enthält AUSSCHLIESSLICH User-Konfigurationen.
    *   **NAS-Skripte:** (z.B. `nas_cloud_sync.sh`, `immich-mover.sh`) dürfen hier NIEMALS existieren oder bearbeitet werden. Diese liegen ausschließlich auf `nas-01:/opt/system-dotfiles/`.
    *   **System-Skripte:** (z.B. Snapshot-Management) liegen ausschließlich in `/opt/system-dotfiles/` auf dem Desktop.
*   **Repo-First:** Änderungen an Skripten MÜSSEN zuerst in den jeweiligen Repositories vorgenommen werden.
*   **Doc-Sync (MANDATORY):** Nach Änderungen an einer `GEMINI.md` muss das Skript `gemini-sync-docs.sh` ausgeführt werden, um alle Repos synchron zu halten.
*   **Deployment:** Nach Repo-Änderung erfolgt das Deployment nach `/usr/local/bin/` (System) oder via `dotfiles-sync.sh` (User).

## 4. Bekannte Fallstricke & Fixes
*   **Permissions:** Skripte in `/opt/system-dotfiles/` benötigen das Executable-Bit.
*   **SSH Auth:** Desktop-Root nutzt `id_ed25519_nas`. User `kevin` nutzt Desktop-Agent-Forwarding (`-A`).
*   **Colors:** `colors.lua` konvertiert `RRGGBBAA` (Env) zu `rgba()` (Hyprland), um Hex-Format-Konflikte (AARRGGBB) zu vermeiden.

## 5. Offene Projekte
- **Paperless-ngx:** Einrichtung geplant (Pfade: SSD für DB/Ingest, HDD für Media).
- **Monitoring:** Grafana/Prometheus Stack auf NAS aktiv (Port 3001/9090 via Caddy).
- **Secret Management (In Progress):**
    *   ✅ Vaultwarden Instanz auf NAS (Port 8080 via HTTPS/Tailscale/Caddy).
    *   ✅ Bitwarden CLI Integration auf Desktop & NAS via API-Keys.
    *   ✅ Dynamische Secret-Injection für `nas_cloud_sync.sh` und `immich-sre.sh`.
    *   ⏳ Backup von SSH-Keys (Private Keys) in den Vault.
    *   ⏳ Migration der `rclone.conf` Tokens in den Vault.
- **Ansible Playbooks:** Automatisierung des System-Setups (Pakete, Admin-Stack, Configs) für Desktop und NAS.
    *   *Status:* `admin_stack` Rolle verwaltet Docker-Services (Caddy, Prometheus, Grafana, Semaphore).
    *   *Backup:* Ansible stellt nur Infrastruktur/Pakete bereit; Skripte verbleiben in `/opt/system-dotfiles/`.
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
