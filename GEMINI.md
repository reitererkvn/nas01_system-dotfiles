# NAS-01 System Configuration Context
**Repo:** /opt/system-dotfiles/ (on nas-01)
**Rolle:** Backup Storage, HDD Management & Immich Tiering

## 1. NAS Kern-Komponenten
- **Storage:** MergerFS (SSD + HDD) unter /lib/immich.
- **Backup:** nas_cloud_sync.sh (Restic). Triggered durch homeserver-cloud-backup.path.
- **HDD-Management:** hdd-spindown.timer zur Stromeinsparung.

## 2. Deployment Workflow
1.  Edit in /opt/system-dotfiles/ auf nas-01.
2.  Deploy (erfordert sudo): sudo cp -rp /opt/system-dotfiles/<path> /<path>.

## 3. Kontext-Verweise
- **Desktop System:** Siehe desktop:/opt/system-dotfiles/GEMINI.md.
- **User-Space:** Siehe desktop:~/.dotfiles/GEMINI.md.
- **Global:** Siehe desktop:~/.gemini/GEMINI.md.

---
*Repo-First Pflicht: NAS-Änderungen immer erst hier commiten.*
