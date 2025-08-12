#!/bin/bash

#################
# Some commands after running script
##################

# nano /etc/systemd/system/pve-config-backup.service
# [Unit]
# Description=One-shot Proxmox config backup (pve-config-backup.sh)
# Wants=network-online.target
# After=network-online.target

#[Service]
#Type=oneshot
#Environment=BACKUP_ROOT=/home/backups_usb
#Environment=KEEP_DAYS=7
#ExecStart=/usr/local/bin/pve-config-backup.sh
#User=root
#Nice=0

################
### timer #####
###############

# nano /etc/systemd/system/pve-config-backup.timer
# [Unit]
#Description=Daily timer for Proxmox config backup

#[Timer]
# #Run every day at 18:00 local time. Change to suit your schedule.
#OnCalendar=*-*-* 18:00:00
#Persistent=true
#Unit=pve-config-backup.service

#[Install]
#WantedBy=timers.target

#systemctl daemon-reload
#systemctl enable --now pve-config-backup.timer
#systemctl start pve-config-backup.service   # run once to test immediately

##########################
### Actual script Down ###
##########################

# pve-config-backup.sh
# nano /usr/local/bin/pve-config-backup.sh
# chmod +x  /usr/local/bin/pve-config-backup.sh

# Full Proxmox config backup to a mounted backup location (USB/NAS).
# - Creates timestamped folder under $BACKUP_ROOT/configs_backups/
# - Creates pve_configs_<ts>.tar.gz and a .sha256 checksum
# - Prunes older backups older than $KEEP_DAYS
# - Exits non-zero on unexpected failures (strict mode)

set -euo pipefail
IFS=$'\n\t'

# === CONFIG ===
BACKUP_ROOT="${BACKUP_ROOT:-/home/backups_usb}"   # Change this or export BACKUP_ROOT before running
KEEP_DAYS="${KEEP_DAYS:-7}"                      # retention in days
LOGFILE="${BACKUP_ROOT}/backup.log"
PREFIX="pve_configs"
TIMESTAMP="$(date +%F_%H-%M-%S)"
DEST_DIR="${BACKUP_ROOT}/configs_backups/${PREFIX}_${TIMESTAMP}"
TARFILE="${DEST_DIR}/${PREFIX}_${TIMESTAMP}.tar.gz"
SUMFILE="${TARFILE}.sha256"
PVEVERSION_FILE="${DEST_DIR}/pveversion_${TIMESTAMP}.txt"

# Paths to include in backup (add/remove as you like)
BACKUP_PATHS=(
  /etc/pve
  /etc/network/interfaces
  /etc/network/interfaces.d
  /etc/network/
  /etc/hosts
  /etc/hostname
  /etc/resolv.conf
  /etc/fstab
  /etc/apt/sources.list
  /etc/apt/sources.list.d
  /etc/ssh
  /root/.ssh
  /etc/default
  /etc/systemd/system
  /etc/modprobe.d
  /etc/modules-load.d
  /etc/udev/rules.d
  /var/lib/pve-cluster
  /etc/pve/local
  /etc/pve/priv
  /etc/pve/storage.cfg
  /etc/pve/datacenter.cfg
  /etc/pve/qemu-server
  /etc/pve/lxc
)

# Sensitive data warning that we'll log (user knows)
INFO_PREFIX="$(date +%F_%T) [pve-backup]"

# === FUNCTIONS ===
log() {
  mkdir -p "$(dirname "$LOGFILE")"
  echo "$INFO_PREFIX $*" | tee -a "$LOGFILE"
}

fail() {
  echo "$INFO_PREFIX ERROR: $*" | tee -a "$LOGFILE" >&2
  exit 1
}

# === CHECKS ===
if [ "$(id -u)" -ne 0 ]; then
  fail "This script must be run as root."
fi

if ! mountpoint -q "$BACKUP_ROOT"; then
  fail "Backup root '$BACKUP_ROOT' is not a mounted filesystem. Mount your USB/NAS and retry."
fi

log "Starting backup into $DEST_DIR (keeping $KEEP_DAYS days)."

# Create destination
mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"

# Save pve version + package list to help future restore
if command -v pveversion &>/dev/null; then
  pveversion -v > "$PVEVERSION_FILE" 2>&1 || true
else
  uname -a > "$PVEVERSION_FILE"
fi

# Create the tarball. --ignore-failed-read allows continuing if a listed path is absent.
# Using absolute paths so restore is straightforward.
log "Creating tarball $TARFILE ..."
tar --warning=no-file-changed --ignore-failed-read -czf "$TARFILE" "${BACKUP_PATHS[@]}" || {
  # tar returns non-zero if *all* files are missing; but with --ignore-failed-read we'll usually be fine.
  log "tar finished (some paths may have been missing)."
}

# Create checksum
log "Creating checksum $SUMFILE ..."
sha256sum "$TARFILE" > "$SUMFILE"

# Add some metadata
echo "Backup: ${PREFIX}_${TIMESTAMP}" > "${DEST_DIR}/README.txt"
echo "Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ") (UTC)" >> "${DEST_DIR}/README.txt"
echo "Source host: $(hostname -f)" >> "${DEST_DIR}/README.txt"
echo "Backup paths:" >> "${DEST_DIR}/README.txt"
printf '  %s\n' "${BACKUP_PATHS[@]}" >> "${DEST_DIR}/README.txt"

log "Backup created successfully: $TARFILE"

# === PRUNE OLD BACKUPS ===
log "Pruning backups older than ${KEEP_DAYS} days in ${BACKUP_ROOT}/configs_backups ..."
# -mindepth 1 prevents deleting the configs_backups root itself
find "${BACKUP_ROOT}/configs_backups" -maxdepth 1 -mindepth 1 -type d -name "${PREFIX}_*" -mtime +${KEEP_DAYS} -print -exec rm -rf {} \; || true

log "Prune complete. Current backups:"
ls -lh "${BACKUP_ROOT}/configs_backups" | sed -n '1,200p' >> "$LOGFILE" || true

log "Backup job finished."

exit 0
