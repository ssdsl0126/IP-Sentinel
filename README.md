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
- GitHub Actions push generated data to `automation/*` branches instead of directly to `main`.

Runtime integrations that still exist because they are core product dependencies:

- Telegram Bot API
- Google services used by the Google simulation and trends fetcher
- Target websites configured in region data files
- IP quality services used by the local quality probe module

## Repository Layout

```text
.
|-- .github/workflows/   GitHub Actions for keyword, trust URL, and user-agent maintenance
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

## Automatic Maintenance

- Agent maintenance runs through `core/runner.sh`.
- Current upstream runtime schedules maintenance every 20 minutes via systemd timers where available, with cron/OpenRC fallback.
- `core/runner.sh` closes the inherited lock FD when starting child modules, so Google correction and trust cleaning are not blocked by a stale `flock`.
- GitHub automation refreshes keyword, region trust URL, and user-agent data into automation branches for review.

## Time Sync Requirement

Master and Agent must keep system time synchronized.

If clocks drift too far apart, webhook requests can fail with:

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

## Source of Truth

The supported runtime source for this fork is:

[https://github.com/ssdsl0126/IP-Sentinel](https://github.com/ssdsl0126/IP-Sentinel)
