# NAS01 System Dotfiles

## Overview
Source of Truth for NAS-specific system services and scripts.

## Managed Services
- **Caddy:** Reverse proxy with Tailscale TLS.
- **Semaphore:** Ansible automation engine.
- **Backup:** `nas_cloud_sync.sh` (Restic to Google Drive).

## Deployment
Scripts are managed in `usr/local/bin/` and must be manually copied to the live system path after changes:
`sudo cp usr/local/bin/* /usr/local/bin/`

---
*Refer to GEMINI.md for architectural rules.*
