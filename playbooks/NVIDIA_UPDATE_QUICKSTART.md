# NVIDIA Driver Update - Quick Start Guide

**Important:** Run all commands from the **project root** (`svw-ansible/`). The `ansible.cfg` there automatically picks up the inventory — no `-i` flag required.

```bash
# Make sure you're in the right place
cd /path/to/svw-ansible
```

## What This Playbook Does

The `playbooks/labelers.yml` playbook handles NVIDIA driver updates across all labeler machines:

✅ **Checks kernel compatibility** (kernel 6.14 requires driver 570+)  
✅ **Cleans up conflicting APT repos and GPG keys**  
✅ **Sets up NVIDIA and container toolkit repositories**  
✅ **Installs NVIDIA driver 570 and CUDA 12.8**  
✅ **Installs nvidia-container-toolkit for Docker GPU support**  
✅ **Configures Docker with NVIDIA runtime**  
✅ **Verifies installation and provides clear feedback**

---

## Quick Commands

### 0. Pre-Flight Checks
```bash
# Confirm all labeler machines are reachable
ansible labeler-machines -m ping

# Check current kernel versions
ansible labeler-machines -m shell -a "uname -r" --become

# Check current driver state (expected to show mismatch/missing before update)
ansible labeler-machines -m shell -a "nvidia-smi --version 2>/dev/null || echo 'Not installed / mismatch'" --become
```

### 1. Test on One Machine First (RECOMMENDED)
```bash
# Deploy to svw-ls-02
ansible-playbook playbooks/labelers.yml --limit svw-ls-02

# Reboot to load new kernel modules
ansible labeler-machines -m reboot --limit svw-ls-02 --become

# Wait 2-3 minutes, then verify
ansible labeler-machines -m shell -a "nvidia-smi" --limit svw-ls-02 --become
```

### 2. Dry Run (Check What Would Change)
```bash
ansible-playbook playbooks/labelers.yml --check --diff --limit svw-ls-02
```

### 3. Deploy to All 13 Machines
```bash
# Deploy to all labeler machines at once
ansible-playbook playbooks/labelers.yml

# Reboot all sequentially to avoid network congestion
ansible labeler-machines -m reboot --become --forks 1

# Wait 20-30 minutes, then verify all
ansible labeler-machines -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader" --become
```

### 4. Deploy in Batches (if you want to be cautious)
```bash
# Batch 1
ansible-playbook playbooks/labelers.yml --limit 'svw-ls-00,svw-ls-01,svw-ls-03,svw-ls-04'
ansible labeler-machines -m reboot --limit 'svw-ls-00,svw-ls-01,svw-ls-03,svw-ls-04' --become

# Batch 2
ansible-playbook playbooks/labelers.yml --limit 'svw-ls-05,svw-ls-06,svw-ls-07,svw-ls-08'
ansible labeler-machines -m reboot --limit 'svw-ls-05,svw-ls-06,svw-ls-07,svw-ls-08' --become

# Batch 3
ansible-playbook playbooks/labelers.yml --limit 'svw-ls-09,svw-ls-10,svw-ls-11,svw-ls-12'
ansible labeler-machines -m reboot --limit 'svw-ls-09,svw-ls-10,svw-ls-11,svw-ls-12' --become
```

---

## What to Expect

### During Playbook Execution
1. **Configuration display** — shows kernel version and target driver versions
2. **Repo cleanup** — removes conflicting NVIDIA/CUDA/vendor repo configs
3. **Repository setup** — adds fresh NVIDIA CUDA and container toolkit repos
4. **Kernel compatibility check** — fails early if kernel 6.14+ with driver < 570
5. **Package installation** — installs driver 570, CUDA 570, nvidia-container-toolkit
6. **Docker configuration** — sets up NVIDIA runtime in `/etc/docker/daemon.json`
7. **Verification** — runs `nvidia-smi` and reports result

### After Playbook Completes
**Important:** The playbook will show:
- ✅ **Driver installed** — but **reboot still required** to load new kernel modules
- ❌ **nvidia-smi failed** — this is **expected before reboot**

**You MUST reboot each machine** for the driver to activate.

---

## Verification After Reboot

### Check Driver Version
```bash
ansible labeler-machines -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader" --become
```
Expected output on each host: `580.x.x` (Ubuntu 24.04 manages 580 as the current driver)

### Check Full nvidia-smi Output
```bash
ansible labeler-machines -m shell -a "nvidia-smi | head -5" --become
```
Should show:
```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.x.xx               Driver Version: 580.x.xx       CUDA Version: 12.9     |
```

### Test Docker GPU Access
```bash
ansible labeler-machines -m shell -a "docker run --rm nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi" --become
```

---

## Troubleshooting

### Playbook fails with "Kernel 6.14 requires driver 570+"
**Cause:** Safety check caught a kernel/driver mismatch before changes were made.  
**Solution:** This is correct behavior. The playbook will install driver 570 — just re-run.

### `nvidia-smi` shows "Driver/library version mismatch"
**Cause:** Old kernel modules are still loaded from the previous boot.  
**Solution:** Reboot the affected machine:
```bash
ansible labeler-machines -m reboot --limit <hostname> --become
```

### `nvidia-smi: command not found`
**Cause:** Package installation failed.  
**Solution:** Check APT logs and re-run the playbook:
```bash
ansible labeler-machines -m shell -a "tail -50 /var/log/apt/history.log" --limit <hostname> --become
ansible-playbook playbooks/labelers.yml --limit <hostname>
```

### Docker can't access GPU
**Cause:** Docker runtime not configured (or daemon.json was overwritten).  
**Solution:**
```bash
ansible labeler-machines -m shell -a "nvidia-ctk runtime configure --runtime=docker && systemctl restart docker" --limit <hostname> --become
```

---

## Pre-Flight Checklist

- [ ] Vault file exists and is readable: `vault.yml`
- [ ] All machines reachable: `ansible labeler-machines -m ping`
- [ ] Current kernel versions checked: `ansible labeler-machines -m shell -a "uname -r" --become`
- [ ] Current driver state noted: `ansible labeler-machines -m shell -a "nvidia-smi --version 2>/dev/null || echo 'missing'" --become`
- [ ] Maintenance window scheduled (machines will need reboot)
- [ ] Users notified of potential downtime

## Post-Deployment Checklist

- [ ] `nvidia-smi` works on all machines
- [ ] Driver version is 570.x: `ansible labeler-machines -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader" --become`
- [ ] CUDA version is 12.8
- [ ] Docker GPU access works
- [ ] Labeling pipeline containers function normally
- [ ] Monitor for errors 24-48 hours

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `ansible-playbook playbooks/labelers.yml` | Deploy to all labeler machines |
| `ansible-playbook playbooks/labelers.yml --limit <host>` | Deploy to a specific host |
| `ansible-playbook playbooks/labelers.yml --check` | Dry run (no changes) |
| `ansible labeler-machines -m reboot --become` | Reboot all labeler machines |
| `ansible labeler-machines -m reboot --become --forks 1` | Reboot all, one at a time |
| `ansible labeler-machines -m shell -a "nvidia-smi" --become` | Check nvidia-smi on all |
| `ansible labeler-machines -m ping` | Confirm all hosts are reachable |

---

**For detailed documentation, see:**
- `playbooks/NVIDIA_UPGRADE_NOTES.md` — Technical details
- `playbooks/LABELERS_DEPLOYMENT_COMMANDS.md` — Extended command reference
- `roles/svwi-labelers/` — Role implementation
