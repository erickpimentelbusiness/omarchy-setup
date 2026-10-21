#!/usr/bin/env bash
# Root part of the local AI setup. Run once with: sudo bash ~/ai-setup/setup-root.sh
#
# 1. Mounts the 2 TB exFAT SSD at /mnt/ssd on every boot.
# 2. Creates a 30 GB ext4 image file on it and mounts it at /mnt/ai, so Docker,
#    Open WebUI and the Ollama binaries get a real Linux filesystem without
#    reformatting the SSD. Kept small because exFAT zero-fills the whole file
#    on first write (~30 MB/s). The models live directly on exFAT instead.
# 3. Moves Docker's storage to /mnt/ai/docker and starts Open WebUI.
set -euo pipefail

SSD_UUID="7806-A4C1"
OWNER="vorcaro"
IMG=/mnt/ssd/linux-ai.img
IMG_SIZE=30G
WEBUI_IMAGE=ghcr.io/open-webui/open-webui:v0.12.3

[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
uid=$(id -u "$OWNER"); gid=$(id -g "$OWNER")

echo "==> fstab (backup at /etc/fstab.bak-ai-setup)"
cp -n /etc/fstab /etc/fstab.bak-ai-setup
mkdir -p /mnt/ssd /mnt/ai
grep -q "$SSD_UUID" /etc/fstab || cat >> /etc/fstab <<EOF

# 2 TB external SSD (exFAT, shared with Windows)
UUID=$SSD_UUID  /mnt/ssd  exfat  nofail,noatime,uid=$uid,gid=$gid,fmask=0022,dmask=0022,x-systemd.device-timeout=10s  0 0
# Linux filesystem image on the SSD: Ollama binaries, Docker, Open WebUI
$IMG  /mnt/ai  ext4  loop,nofail,noatime,x-systemd.requires-mounts-for=/mnt/ssd  0 0
EOF
systemctl daemon-reload

echo "==> Mounting SSD at /mnt/ssd"
if ! mountpoint -q /mnt/ssd; then
  umount /run/media/"$OWNER"/SSD 2>/dev/null || true
  mount /mnt/ssd
fi

echo "==> Creating $IMG_SIZE image"
if [[ ! -f $IMG ]]; then
  fallocate -l "$IMG_SIZE" "$IMG"
  mkfs.ext4 -q -L linux-ai -m 0 "$IMG"
fi
mountpoint -q /mnt/ai || mount /mnt/ai
chown "$uid:$gid" /mnt/ai

echo "==> Docker storage on /mnt/ai/docker"
mkdir -p /mnt/ai/docker /etc/systemd/system/docker.service.d
python3 - <<'EOF'
import json, pathlib
p = pathlib.Path("/etc/docker/daemon.json")
cfg = json.loads(p.read_text()) if p.exists() else {}
cfg["data-root"] = "/mnt/ai/docker"
p.write_text(json.dumps(cfg, indent=4) + "\n")
EOF
cat > /etc/systemd/system/docker.service.d/ai-mount.conf <<'EOF'
[Unit]
RequiresMountsFor=/mnt/ai
EOF
systemctl daemon-reload
systemctl enable --now docker
systemctl restart docker

echo "==> Open WebUI (only reachable from this PC, no telemetry)"
mkdir -p /mnt/ai/open-webui
docker rm -f open-webui >/dev/null 2>&1 || true
docker run -d --name open-webui --restart unless-stopped --network host \
  -v /mnt/ai/open-webui:/app/backend/data \
  -e HOST=127.0.0.1 -e PORT=3000 \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  -e WEBUI_AUTH=False \
  -e ANONYMIZED_TELEMETRY=false -e DO_NOT_TRACK=true -e SCARF_NO_ANALYTICS=true \
  -e ENABLE_VERSION_UPDATE_CHECK=false \
  "$WEBUI_IMAGE"

echo
echo "Done. SSD: /mnt/ssd   AI storage: /mnt/ai   Open WebUI: http://127.0.0.1:3000"
df -h /mnt/ssd /mnt/ai
