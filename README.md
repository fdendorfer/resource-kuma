# resource-kuma

Lightweight host resource monitor with a web dashboard. Zero runtime dependencies — just bash, python3 (stdlib only), and a static file server.

**Collects every 30s:** CPU %, memory used/total, per-container memory usage and limits (if Docker is present). Keeps a rolling 24h window.

![dashboard showing CPU and memory line graphs with container bars]

## Install

```bash
git clone https://github.com/fdendorfer/resource-kuma
cd resource-kuma
sudo bash install.sh
```

Then serve `dashboard/` (at `/opt/resource-kuma/dashboard`) with any static file server.

## What it installs

| Path | Purpose |
|---|---|
| `/opt/resource-kuma/collect.sh` | Collector script |
| `/var/lib/resource-kuma/data.json` | Rolling 24h data (2880 points) |
| `/opt/resource-kuma/dashboard/` | Static dashboard (index.html + data.json symlink) |
| `resource-kuma-collect.timer` | systemd timer, fires every 30s |
| `resource-kuma-collect.service` | systemd oneshot service |

## Configuration

Environment variables for `collect.sh`:

| Variable | Default | Description |
|---|---|---|
| `RESOURCE_KUMA_DATA_DIR` | `/var/lib/resource-kuma` | Where data.json is stored |

## Uninstall

```bash
systemctl disable --now resource-kuma-collect.timer
rm /etc/systemd/system/resource-kuma-collect.{service,timer}
rm -rf /opt/resource-kuma /var/lib/resource-kuma
systemctl daemon-reload
```
