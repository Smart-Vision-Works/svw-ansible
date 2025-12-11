# NVIDIA Driver Update - Quick Start Guide

## What This Playbook Does

The updated `labelers.yml` playbook is now **focused specifically** on NVIDIA driver updates:

✅ **Checks kernel compatibility** (kernel 6.14 requires driver 570+)  
✅ **Sets up NVIDIA and container toolkit repositories**  
✅ **Installs NVIDIA driver 570 and CUDA 12.8**  
✅ **Installs nvidia-container-toolkit for Docker GPU support**  
✅ **Configures Docker with NVIDIA runtime**  
✅ **Verifies installation and provides clear feedback**

## Quick Commands

### 1. Test on One Machine First (RECOMMENDED)
```bash
# Deploy to svw-ls-02 (already manually tested)
ansible-playbook -i inventory.ini labelers.yml --limit svw-ls-02

# Reboot to load new kernel modules
ansible labeler-machines -i inventory.ini -m reboot --limit svw-ls-02 --become

# Wait 2-3 minutes, then verify
ansible labeler-machines -i inventory.ini -m shell -a "nvidia-smi" --limit svw-ls-02 --become
```

### 2. Deploy to Multiple Machines
```bash
# Deploy to first 4 machines
ansible-playbook -i inventory.ini labelers.yml --limit 'svw-ls-00,svw-ls-01,svw-ls-02,svw-ls-03'

# Reboot them
ansible labeler-machines -i inventory.ini -m reboot --limit 'svw-ls-00,svw-ls-01,svw-ls-02,svw-ls-03' --become
```

### 3. Deploy to All 13 Machines
```bash
# Deploy to all labeler machines
ansible-playbook -i inventory.ini labelers.yml

# Reboot all (sequentially to avoid network congestion)
ansible labeler-machines -i inventory.ini -m reboot --become --forks 1
```

### 4. Dry Run (Check What Would Change)
```bash
# See what would change without making changes
ansible-playbook -i inventory.ini labelers.yml --check --diff --limit svw-ls-02
```

## What to Expect

### During Playbook Execution
You'll see:
1. **Configuration display** - Shows kernel version and target driver versions
2. **Repository setup** - Adds NVIDIA CUDA and container toolkit repos
3. **Kernel compatibility check** - Fails if kernel 6.14+ with driver < 570 (safety feature!)
4. **Package installation** - Installs driver 570, CUDA 570, nvidia-container-toolkit
5. **Docker configuration** - Sets up NVIDIA runtime
6. **Verification** - Checks if nvidia-smi works

### After Playbook Completes
**Important:** The playbook will show:
- ✅ **If driver installed successfully** - But **reboot required** to load kernel modules
- ❌ **If nvidia-smi fails** - This is **expected** until reboot

**You MUST reboot the machine** for the driver to activate!

## Verification After Reboot

### Check Driver Version
```bash
ansible labeler-machines -i inventory.ini -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader" --limit svw-ls-02 --become
```

Expected output: `570.195.03` (or similar 570.x version)

### Check Full nvidia-smi Output
```bash
ansible labeler-machines -i inventory.ini -m shell -a "nvidia-smi | head -5" --limit svw-ls-02 --become
```

Should show:
```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 570.195.03             Driver Version: 570.195.03     CUDA Version: 12.8     |
```

### Test Docker GPU Access
```bash
ansible labeler-machines -i inventory.ini -m shell -a "docker run --rm nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi" --limit svw-ls-02 --become
```

Should show GPU information from inside the container.

## Deployment Strategy

### Conservative (Recommended for Production)
```bash
# Day 1: Test machine
ansible-playbook -i inventory.ini labelers.yml --limit svw-ls-02
ansible labeler-machines -i inventory.ini -m reboot --limit svw-ls-02 --become
# Monitor for 24 hours

# Day 2: First batch (4 machines)
ansible-playbook -i inventory.ini labelers.yml --limit 'svw-ls-00,svw-ls-01,svw-ls-03,svw-ls-04'
ansible labeler-machines -i inventory.ini -m reboot --limit 'svw-ls-00,svw-ls-01,svw-ls-03,svw-ls-04' --become
# Monitor for 24 hours

# Day 3: Second batch (4 machines)
ansible-playbook -i inventory.ini labelers.yml --limit 'svw-ls-05,svw-ls-06,svw-ls-07,svw-ls-08'
ansible labeler-machines -i inventory.ini -m reboot --limit 'svw-ls-05,svw-ls-06,svw-ls-07,svw-ls-08' --become

# Day 4: Final batch (5 machines)
ansible-playbook -i inventory.ini labelers.yml --limit 'svw-ls-09,svw-ls-10,svw-ls-11,svw-ls-12'
ansible labeler-machines -i inventory.ini -m reboot --limit 'svw-ls-09,svw-ls-10,svw-ls-11,svw-ls-12' --become
```

### Aggressive (If Downtime is Acceptable)
```bash
# Deploy all at once
ansible-playbook -i inventory.ini labelers.yml

# Reboot all sequentially
ansible labeler-machines -i inventory.ini -m reboot --become --forks 1

# Wait 20-30 minutes, then verify all
ansible labeler-machines -i inventory.ini -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader" --become
```

## Troubleshooting

### Playbook Fails with "Kernel 6.14 requires driver 570+"
**Cause:** Safety check detected kernel/driver mismatch  
**Solution:** This is correct behavior! The playbook will install driver 570. Just re-run if it stopped early.

### nvidia-smi Shows "Driver/library version mismatch"
**Cause:** Old kernel modules still loaded  
**Solution:** Reboot the machine
```bash
ansible labeler-machines -i inventory.ini -m reboot --limit <hostname> --become
```

### nvidia-smi Command Not Found
**Cause:** Package installation failed  
**Solution:** Check APT logs and re-run playbook
```bash
ansible labeler-machines -i inventory.ini -m shell -a "tail -50 /var/log/apt/history.log" --limit <hostname> --become
```

### Docker Can't Access GPU
**Cause:** Docker runtime not configured  
**Solution:** Re-run nvidia-ctk configuration
```bash
ansible labeler-machines -i inventory.ini -m shell -a "nvidia-ctk runtime configure --runtime=docker && systemctl restart docker" --limit <hostname> --become
```

## Pre-Flight Checklist

Before deploying to production:

- [ ] ✅ Vault file exists and is readable (`vault.yml`)
- [ ] ✅ All machines are reachable: `ansible labeler-machines -i inventory.ini -m ping`
- [ ] ✅ Check current kernel versions: `ansible labeler-machines -i inventory.ini -m shell -a "uname -r" --become`
- [ ] ✅ Check current driver versions: `ansible labeler-machines -i inventory.ini -m shell -a "nvidia-smi --version 2>/dev/null || echo 'Not installed'" --become`
- [ ] ✅ Backup any critical data on target machines
- [ ] ✅ Schedule maintenance window (machines will need reboot)
- [ ] ✅ Notify users of potential downtime

## Post-Deployment Checklist

After deployment and reboot:

- [ ] ✅ Verify nvidia-smi works on all machines
- [ ] ✅ Verify correct driver version (570.x)
- [ ] ✅ Verify CUDA version (12.8)
- [ ] ✅ Test Docker GPU access
- [ ] ✅ Test labeling pipeline containers
- [ ] ✅ Monitor for errors for 24-48 hours
- [ ] ✅ Update documentation with any issues encountered

## Files Modified by This Playbook

- `/usr/share/keyrings/nvidia-*.gpg` - Repository GPG keys
- `/etc/apt/sources.list.d/nvidia-*.list` - Repository configurations
- NVIDIA driver packages (driver 570.x)
- `/etc/docker/daemon.json` - Docker NVIDIA runtime configuration
- Kernel modules: nvidia, nvidia_uvm, nvidia_drm, nvidia_modeset

## Success Criteria

After successful deployment, each machine should have:

✅ **Driver:** 570.195.03 or newer  
✅ **CUDA:** 12.8  
✅ **nvidia-smi:** Working without errors  
✅ **Docker:** Can run GPU containers  
✅ **Kernel modules:** nvidia modules loaded (`lsmod | grep nvidia`)  

## Quick Reference

| Command | Purpose |
|---------|---------|
| `ansible-playbook -i inventory.ini labelers.yml --limit <host>` | Deploy to specific host |
| `ansible labeler-machines -i inventory.ini -m reboot --become` | Reboot all machines |
| `ansible labeler-machines -i inventory.ini -m shell -a "nvidia-smi"` | Check nvidia-smi |
| `ansible-playbook -i inventory.ini labelers.yml --check` | Dry run (no changes) |

---

**For detailed documentation, see:**
- `roles/svwi-labelers/NVIDIA_UPGRADE_NOTES.md` - Technical details
- `roles/svwi-labelers/DEPLOYMENT_COMMANDS.md` - All commands
- `roles/svwi-labelers/CHANGES_SUMMARY.md` - What changed and why

