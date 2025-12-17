# Quick Deployment Commands for Labeler Machines

**Note:** Your inventory has 13 labeler machines (svw-ls-00 through svw-ls-12) in group `labeler-machines`

**Important:** All commands should be run from the `playbooks/` directory. If you're in the ansible root, run `cd playbooks` first.

## Pre-Deployment Checks

### 1. Check connectivity to all machines
```bash
ansible labeler-machines -i ../inventory.ini -m ping
```

### 2. Check kernel versions
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "uname -r" --become
```

### 3. Check current NVIDIA driver versions (if installed)
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'No driver installed'" --become
```

### 4. Check current CUDA versions
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-smi | grep -oP 'CUDA Version: \K[0-9.]+' 2>/dev/null || echo 'N/A'" --become
```

## Deployment Options

### Option A: Test on One Machine First (RECOMMENDED)
```bash
# Test on svw-ls-02 (already manually tested with driver 570)
ansible-playbook -i ../inventory.ini labelers.yml --limit svw-ls-02

# Reboot test machine
ansible labeler-machines -i ../inventory.ini -m reboot -a "reboot_timeout=600" --limit svw-ls-02 --become

# Wait 2-3 minutes, then verify
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-smi" --limit svw-ls-02 --become

# Test Docker GPU access
ansible labeler-machines -i ../inventory.ini -m shell -a "docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi" --limit svw-ls-02 --become
```

### Option B: Rolling Deployment (Batches of 4)
```bash
# Batch 1 (svw-ls-00 through svw-ls-03)
ansible-playbook -i ../inventory.ini labelers.yml --limit 'svw-ls-00,svw-ls-01,svw-ls-02,svw-ls-03'
ansible labeler-machines -i ../inventory.ini -m reboot --limit 'svw-ls-00,svw-ls-01,svw-ls-02,svw-ls-03' --become

# Batch 2 (svw-ls-04 through svw-ls-07)
ansible-playbook -i ../inventory.ini labelers.yml --limit 'svw-ls-04,svw-ls-05,svw-ls-06,svw-ls-07'
ansible labeler-machines -i ../inventory.ini -m reboot --limit 'svw-ls-04,svw-ls-05,svw-ls-06,svw-ls-07' --become

# Batch 3 (svw-ls-08 through svw-ls-11)
ansible-playbook -i ../inventory.ini labelers.yml --limit 'svw-ls-08,svw-ls-09,svw-ls-10,svw-ls-11'
ansible labeler-machines -i ../inventory.ini -m reboot --limit 'svw-ls-08,svw-ls-09,svw-ls-10,svw-ls-11' --become

# Batch 4 (svw-ls-12)
ansible-playbook -i ../inventory.ini labelers.yml --limit svw-ls-12
ansible labeler-machines -i ../inventory.ini -m reboot --limit svw-ls-12 --become
```

### Option C: Deploy to All Machines at Once
```bash
# Deploy to all labeler machines (13 machines: svw-ls-00 through svw-ls-12)
ansible-playbook -i ../inventory.ini labelers.yml

# Reboot all (one at a time with forks=1 to avoid overwhelming network)
ansible labeler-machines -i ../inventory.ini -m reboot -a "reboot_timeout=600" --become --forks 1
```

### Option D: Deploy with Tags (NVIDIA setup only)
```bash
# Only run NVIDIA-related tasks
ansible-playbook -i ../inventory.ini labelers.yml --tags nvidia

# Then reboot
ansible labeler-machines -i ../inventory.ini -m reboot --become --forks 3
```

## Post-Deployment Verification

### 1. Verify all machines are up
```bash
ansible labeler-machines -i ../inventory.ini -m ping
```

### 2. Check NVIDIA driver versions on all machines
```bash
# Check driver version
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-smi --query-gpu=driver_version --format=csv,noheader" --become

# Or get both driver and CUDA version from header
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-smi | head -3 | tail -1" --become
```

Expected output for each machine:
```
570.195.03
# OR from the header:
| NVIDIA-SMI 570.195.03             Driver Version: 570.195.03     CUDA Version: 12.8     |
```

### 3. Verify Docker GPU access on all machines
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "docker run --rm nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi | grep 'Driver Version'" --become
```

### 4. Check Docker daemon configuration
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "grep default-runtime /etc/docker/daemon.json" --become
```

Should show:
```
"default-runtime": "nvidia",
```

### 5. Generate summary report
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "echo \"Host: \$(hostname) | Kernel: \$(uname -r) | Driver: \$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'ERROR') | CUDA: \$(nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9.]+' || echo 'ERROR')\"" --become
```

## Troubleshooting Commands

### Check for machines with driver mismatch errors
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-smi 2>&1 | grep -i mismatch || echo 'OK'" --become
```

### Check Docker service status on all machines
```bash
ansible labeler-machines -i ../inventory.ini -m systemd -a "name=docker state=started" --become
```

### Restart Docker on all machines
```bash
ansible labeler-machines -i ../inventory.ini -m systemd -a "name=docker state=restarted" --become
```

### Re-run nvidia-ctk configuration on specific machine
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-ctk runtime configure --runtime=docker && systemctl restart docker" --limit svw-ls-02 --become
```

### Check for kernel module issues
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "lsmod | grep nvidia" --become
```

### View recent dmesg errors related to NVIDIA
```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "dmesg | grep -i nvidia | tail -20" --become
```

## Emergency Rollback (Only for kernel < 6.14)

⚠️ **WARNING:** This will NOT work on machines running kernel 6.14+

```bash
# 1. Update role defaults back to 565
# Edit defaults/main.yml:
#   nvidia_driver_version: "565"
#   nvidia_cuda_version: "565"

# 2. Re-run playbook
ansible-playbook -i ../inventory.ini labelers.yml

# 3. Reboot all machines
ansible labeler-machines -i ../inventory.ini -m reboot --become --forks 2
```

## Testing Labeling Pipeline

After deployment, test the actual labeling pipeline:

```bash
# SSH to a labeler machine
ssh jhansen@svw-ls-02

# Navigate to model development
cd /auto/ds/model_development

# Test the docker container
CUDA_VISIBLE_DEVICES=0 ./docker_run.sh

# Inside container, verify GPU access
nvidia-smi
```

## Monitoring During Deployment

### Watch deployment progress in real-time
```bash
# In one terminal, watch ansible output
ansible-playbook -i ../inventory.ini labelers.yml -v

# In another terminal, watch machine status
watch -n 5 'ansible labeler-machines -i ../inventory.ini -m ping --one-line'
```

### Create deployment log
```bash
ansible-playbook -i ../inventory.ini labelers.yml | tee deployment-$(date +%Y%m%d-%H%M%S).log
```

## Contact for Issues
- Driver/library version mismatch → Reboot required
- nvidia-smi command not found → Package installation failed, check APT logs
- Docker GPU errors → Run `nvidia-ctk runtime configure --runtime=docker`
- Kernel 6.14 incompatibility → Must use driver 570+

## Performance Baseline

After successful deployment, capture baseline metrics:

```bash
ansible labeler-machines -i ../inventory.ini -m shell -a "nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv" --become
```

