# NVIDIA Driver Upgrade - Kernel 6.14 Compatibility

## Overview
This role has been updated to support Ubuntu systems running kernel 6.14.x with NVIDIA GPUs. The primary change is upgrading from NVIDIA driver 565 to 570, which is required for kernel 6.14 compatibility.

## Changes Made

### 1. Driver Version Updates
- **Old:** `nvidia_driver_version: "565"` → **New:** `nvidia_driver_version: "570"`
- **Old:** `nvidia_cuda_version: "565"` → **New:** `nvidia_cuda_version: "570"`

**Rationale:**
- Kernel 6.14 requires NVIDIA driver 570.26 or newer
- Driver 570.x adds support for CUDA 12.8
- Driver 565.x causes "Driver/library version mismatch" errors on kernel 6.14

### 2. Package Updates
Added `nvidia-container-toolkit` to the package list:
```yaml
nvidia_packages:
  - nvidia-container-toolkit  # NEW - modern container runtime
  - nvidia-docker2            # Legacy compatibility
```

### 3. Enhanced nvidia_setup.yml
- **Kernel Compatibility Check:** Fails early if kernel 6.14+ is detected with driver < 570
- **nvidia-ctk Configuration:** Uses `nvidia-ctk runtime configure --runtime=docker` for proper Docker integration
- **Verification Steps:** Checks nvidia-smi after installation
- **Module Loading:** Ensures nvidia kernel modules are loaded
- **Better Error Handling:** Provides clear feedback on setup status

### 4. Docker Configuration
Updated `docker-daemon.json` to set NVIDIA as default runtime:
```json
{
    "default-runtime": "nvidia",
    ...
}
```

This eliminates the need for `--gpus all` flag in most docker run commands.

## Compatibility Matrix

| Kernel Version | Min NVIDIA Driver | Max CUDA Version | Status |
|----------------|-------------------|------------------|--------|
| 6.11.x         | 565.x            | 12.6             | ✓      |
| 6.14.x         | 570.26+          | 12.8             | ✓      |

## Deployment Considerations

### Pre-Deployment Checks
1. **Check kernel versions on all 12 machines:**
   ```bash
   ansible labelers -i inventory.ini -m shell -a "uname -r"
   ```

2. **Check current NVIDIA driver versions:**
   ```bash
   ansible labelers -i inventory.ini -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader" --become
   ```

### Expected Behavior During Deployment

#### Scenario 1: Clean Install (No existing NVIDIA drivers)
- ✓ Installs driver 570.x
- ✓ Configures Docker runtime
- ⚠️ **Reboot required** for driver to activate

#### Scenario 2: Upgrade from Driver 565 → 570
- ✓ Removes driver 565.x
- ✓ Installs driver 570.x
- ⚠️ **Reboot required** for new driver
- ⚠️ May show nvidia-smi errors until reboot

#### Scenario 3: Already on Driver 570+
- ✓ Validates configuration
- ✓ Updates Docker runtime if needed
- ℹ️ No reboot needed (unless config changed)

### Post-Deployment Verification

1. **Verify driver installation:**
   ```bash
   ansible labelers -i inventory.ini -m shell -a "nvidia-smi" --become
   ```
   
   Expected output should show:
   - Driver Version: 570.x
   - CUDA Version: 12.8

2. **Test Docker GPU access:**
   ```bash
   ansible labelers -i inventory.ini -m shell -a "docker run --rm nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi" --become
   ```

3. **Check for any failed hosts:**
   ```bash
   ansible labelers -i inventory.ini -m shell -a "systemctl status docker" --become
   ```

## Troubleshooting

### Issue: nvidia-smi shows "Failed to initialize NVML: Driver/library version mismatch"
**Solution:** Reboot the machine to load the new kernel module
```bash
ansible labelers -i inventory.ini -a "reboot" --become
```

### Issue: Docker can't find NVIDIA runtime
**Solution:** Re-run the nvidia-ctk configuration
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Issue: Container can't access GPU
**Solution:** Verify Docker daemon configuration
```bash
cat /etc/docker/daemon.json
sudo systemctl restart docker
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi
```

## Rollback Plan

If issues occur, you can rollback to driver 565 (only on kernel < 6.14):

1. **Update defaults/main.yml:**
   ```yaml
   nvidia_driver_version: "565"
   nvidia_cuda_version: "565"
   ```

2. **Run playbook:**
   ```bash
   ansible-playbook -i inventory.ini playbook.yml --tags nvidia
   ```

3. **Reboot machines:**
   ```bash
   ansible labelers -i inventory.ini -a "reboot" --become
   ```

⚠️ **WARNING:** Rollback will NOT work on kernel 6.14.x systems!

## Recommended Deployment Strategy

### Option 1: Phased Rollout (Recommended for Production)
```bash
# Test on 1-2 machines first
ansible-playbook -i inventory.ini playbook.yml --limit labeler-01,labeler-02

# Verify and reboot
ansible labelers -i inventory.ini -m shell -a "nvidia-smi" --limit labeler-01,labeler-02 --become

# Deploy to remaining machines in batches
ansible-playbook -i inventory.ini playbook.yml --limit labeler-03:labeler-06
ansible-playbook -i inventory.ini playbook.yml --limit labeler-07:labeler-12
```

### Option 2: All at Once (For Maintenance Windows)
```bash
# Deploy to all machines
ansible-playbook -i inventory.ini playbook.yml

# Reboot all (with 2-minute delay between hosts)
ansible labelers -i inventory.ini -a "reboot" --become --forks 1
```

## Testing Checklist

After deployment, verify on each machine:
- [ ] nvidia-smi shows driver 570.x
- [ ] nvidia-smi shows CUDA 12.8
- [ ] Docker can run GPU containers
- [ ] Labeling pipeline containers work correctly
- [ ] No kernel module errors in dmesg

## Additional Resources

- [NVIDIA Driver Archive](https://www.nvidia.com/Download/index.aspx)
- [NVIDIA Container Toolkit Docs](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)
- [Kernel 6.14 Compatibility Issues](https://github.com/NVIDIA/open-gpu-kernel-modules/issues)

## Date of Changes
**Updated:** December 4, 2025  
**Updated By:** Based on troubleshooting session with svw-ls-02 kernel 6.14 compatibility issues

