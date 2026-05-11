# 🚀 NAS-01 System Infrastructure: SRE Driven Storage

**NAS-01 System Dotfiles** manage the backbone of the decentralized storage and backup infrastructure. Designed with strict **Site Reliability Engineering (SRE)** principles, this repository ensures data integrity, decoupled event-driven backups, and optimized hardware utilization for the tiered storage architecture.

## ⚙️ Architecture & SRE "Reality"

The NAS is built on a hybrid storage model that separates high-IOPS workloads (Ingest/DB) from cold storage (Archive), connected via smart snapshot and sync logic.

| Principle | Implementation (The Reality) | Context |
| :--- | :--- | :--- |
| **Tiered Storage Abstraction** | `MergerFS` transparently blends SSDs (`/opt/containerd/immich/data`) and HDDs (`/mnt/HDD-01/immich`) into a unified mount (`/lib/immich`). | Balances fast ingest performance with cost-effective bulk storage without confusing the application layer. |
| **Optimized I/O Cycles** | Snapper timelines on the HDD are explicitly DEACTIVATED. Snapshots are only triggered nightly via sync scripts. | Drastically reduces unnecessary HDD wake cycles, extending hardware lifespan and minimizing noise/power draw. |
| **Event-Driven Backups** | Backup jobs (e.g., `nas_cloud_sync.sh`) rely on trigger files (`.sync_done`) rather than strict cron times. | Ensures cloud synchronization only starts *after* local integrity and snapshots are guaranteed, preventing race conditions. |
| **Concurrency & Modularity** | Cloud syncs utilize separated Restic repositories (`homeserver` & `nas`) running in parallel via independent systemd paths. | Prevents monolithic backup jobs from blocking each other; no more `pkill restic` workarounds. |

## 🤖 AI-Assisted Systems Engineering

Like its desktop counterpart, this infrastructure relies on orchestrating Large Language Models (**LLM**) not just for scripting, but for high-level architectural validation. 

*   **The Engine (Gemini LLM):** Used to generate robust systemd units, safe Rsync/Restic wrappers, and complex Btrfs subvolume management scripts.
*   **The Architect (Human):** Focused on defining the constraints—such as "HDD must sleep as much as possible" or "Cloud sync must handle concurrent jobs without locking"—and verifying that the AI-generated solutions adhere strictly to these physical and logical constraints.

## 🛠 Deterministic Infrastructure (IaC)

This system abandons fragile, manual NAS GUI configurations in favor of deterministic file states. Everything from MergerFS definitions to systemd timer triggers is managed as code, allowing the NAS to be easily rebuilt or audited.

## 📦 Repository Structure

*   **`/etc/`**: Systemd units, timer definitions, FSTAB entries, and MergerFS configurations.
*   **`/usr/`**: Custom synchronization scripts, snapshot triggers, and backup execution wrappers.
