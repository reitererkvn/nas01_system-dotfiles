# 🗄 NAS-System: The SRE Data Custodian

**NAS-System** is the Source of Truth for NAS-specific services, storage management, and the final stage of the backup chain. It operates as the "Data Custodian" for the infrastructure, providing high-availability services and long-term archival reliability.

## ⚙️ Core Responsibilities: Storage & Services

This repository manages the "Service Stack" and "Storage Tiering," utilizing a hybrid model to balance performance and capacity.

| Component | Implementation | Purpose |
| :--- | :--- | :--- |
| **Hybrid Storage** | **MergerFS** & **Btrfs** (SSD/HDD tiering). | SSD for active ingest/databases; HDD for cold archival. |
| **Service Hosting** | **Docker/Containerd** orchestration (Caddy, Immich, etc.). | High-performance, isolated application environment. |
| **Ansible Automation** | **Semaphore** (Ansible UI) listener. | Centralized automation UI for multi-host tasks. |
| **Backup Safety** | Restic-based cloud sync (\`nas_cloud_sync.sh\`). | Final off-site encryption and archival to Google Drive. |
| **HDD Management** | Automated spin-down and temperature monitoring. | Extending hardware lifespan via smart logic. |

## 🏗 Storage Tiering (SSD vs. HDD)

The NAS implements a sophisticated tiering logic managed via Systemd timers and custom scripts:
*   **SSD Tier:** Hosts DBs and active files (e.g., Immich Ingest).
*   **HDD Tier:** Massive storage for media and long-term archives.
*   **Tiering Logic:** \`immich-mover.sh\` migrates processed data from SSD to HDD based on event triggers (\`.nas_local_sync.done\`).

## 🛡 Backup Chain (The Final Link)

The NAS represents the final "Point of Truth" for data safety:
1.  **Ingest:** Receives Btrfs snapshots from the Desktop.
2.  **Local Sync:** Synchronizes snapshots to the HDD tier.
3.  **Cloud Sync:** Encrypts and uploads the final state to the cloud.

## 🤖 Remote Orchestration

While the **Ansible Master** lives on the Desktop, the NAS hosts **Semaphore**, providing a centralized interface to trigger playbooks remotely via Tailscale.

## 📜 Key Service Scripts

| Script Name | Purpose |
| :--- | :--- |
| \`nas_local_snapshot_sync.sh\` | Synchronizes incoming Btrfs snapshots from SSD to the HDD archival tier. |
| \`nas_cloud_sync.sh\` | Final stage backup: Encrypts and syncs data to Google Drive. |
| \`immich-mover.sh\` | Manages data tiering between the performance (SSD) and capacity (HDD) layers. |
| \`vault-unlock.sh\` | Manages the secure Bitwarden session token for secret injection. |

---
*Refer to GEMINI.md for architectural rules and SRE guidelines.*
