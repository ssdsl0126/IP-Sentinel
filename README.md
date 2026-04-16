# IP-Sentinel

Self-hosted `Master + Agent` toolkit for region-aware network simulation.

This fork is locked to your own infrastructure:

- Your own GitHub repository: [ssdsl0126/IP-Sentinel](https://github.com/ssdsl0126/IP-Sentinel)
- Your own Telegram Bot token
- Your own Master server
- No public gateway mode
- No install-count telemetry
- No community-channel or third-party tracking links

## Security Model

This repository is intended to be operated only by the repository owner.

- All installer and updater pulls point to `ssdsl0126/IP-Sentinel`.
- Public Telegram gateway mode has been removed.
- External install counters have been removed.
- GitHub Actions no longer push directly to `main`.

Runtime integrations that still exist because they are core product dependencies:

- Telegram Bot API
- Google services used by the Google simulation and trends fetcher
- Target websites configured in region data files

## Repository Layout

```text
.
|-- .github/workflows/   GitHub Actions for keyword and user-agent maintenance
|-- core/                Agent installer, runtime scripts, updater, modules
|-- master/              Master installer and Telegram control plane
|-- scripts/             Data-generation utilities
|-- data/                Regions, keywords, user agents, and map index
`-- README.md            Self-hosted deployment notes
```

## Quick Start

### Mode A: Agent Only

Use this when you want to deploy a single Agent bound to your own Telegram Bot.

```bash
bash <(curl -sL https://raw.githubusercontent.com/ssdsl0126/IP-Sentinel/main/core/install.sh)
```

During setup, provide:

- Your own Telegram Bot token
- Your own chat ID
- Your desired region and port settings

### Mode B: Master + Agent

Use this when you want a central Master that manages one or more Agents.

Install Master:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ssdsl0126/IP-Sentinel/main/master/install_master.sh)
```

Install Agent:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ssdsl0126/IP-Sentinel/main/core/install.sh)
```

## Time Sync Requirement

Master and Agent must keep system time synchronized.

If the clocks drift too far apart, webhook requests can fail with:

```text
401 Unauthorized: Request Expired
```

Recommended checks:

```bash
date
date +%s
timedatectl status
```

Enable NTP with `systemd-timesyncd`:

```bash
timedatectl set-ntp true
systemctl restart systemd-timesyncd
timedatectl status
```

Or with `chrony`:

```bash
apt-get update
apt-get install -y chrony
systemctl enable chrony
systemctl restart chrony
chronyc tracking
```

## Upgrade

Existing deployments can continue using the installer and updater from this repository.

Important:

- Re-deploy only from `ssdsl0126/IP-Sentinel`
- Do not use unknown mirrors
- Keep your GitHub account, PAT, SSH keys, and Telegram Bot token protected

## Uninstall

Agent:

```bash
bash /opt/ip_sentinel/core/uninstall.sh
```

Master:

```bash
printf 'y\n' | bash /opt/ip_sentinel_master/uninstall_master.sh
```

## Region Data

Region support is data-driven.

To add a new region, update:

- `data/map.json`
- `data/regions/<COUNTRY>/<STATE>/<CITY>.json`
- `data/keywords/kw_<COUNTRY>.txt`

## Operational Notes

- Keep Master and Agent on your own servers only.
- Restrict Agent inbound access to your Master IP whenever possible.
- Use a private Telegram chat instead of a group chat.
- Review GitHub Actions and branch protection settings before enabling automation.

## Source of Truth

The only supported upstream for this fork is:

[https://github.com/ssdsl0126/IP-Sentinel](https://github.com/ssdsl0126/IP-Sentinel)