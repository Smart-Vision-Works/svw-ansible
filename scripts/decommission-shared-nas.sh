#!/usr/bin/env bash
# Restores the decommissioned state of the shared NAS (10.10.1.50:/auto/shared)
# after the temporary remount done in playbooks/remount-shared-nas.yml.
#
# Labelers:       labelers-nfs.yml handles unmount + fstab comment-out.
# Singularity/Eureka: unmounted ad-hoc (svwi-datarig still has state: mounted,
#                 so running the full datarig playbook would re-add it).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Decommissioning /auto/shared on labelers ==="
ansible-playbook "$REPO_DIR/playbooks/labelers-nfs.yml"

echo "=== Unmounting /auto/shared on singularity and eureka ==="
ansible datarig_servers \
    -i "$REPO_DIR/inventory/hosts" \
    --become \
    -m ansible.posix.mount \
    -a "path=/auto/shared state=unmounted"

echo "=== Done ==="
