# Edge-OS — Immutable Yocto-Based Linux for NVIDIA Jetson

A production-oriented embedded Linux platform with independent OS, application, and configuration lifecycles, A/B deployment, OTA updates, and rollback.

![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)
![Built with Yocto](https://img.shields.io/badge/Built%20with-Yocto%2FBitBake-orange.svg)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)
![NVIDIA Jetson](https://img.shields.io/badge/Platform-NVIDIA%20Jetson%20Orin%20Nano-76B900.svg)

---

## Quick Navigation

**[Architecture](#architecture)** → **[Demo](#demo)** → **[Technologies](#technologies)** → **[OTA & Rollback](#ota--rollback)** → **[Build Instructions](#build-instructions)**

---

## Architecture

### Layered Separation Model

Edge-OS enforces strict separation between **immutable OS**, **mutable applications**, and **configuration**:

```
┌─────────────────────────────────────────────────────────────┐
│                    EDGE-OS LAYER STACK                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Configuration Extensions (confext)                  │   │
│  │  └─ Drop-in configs, systemd units, overlays        │   │
│  └──────────────────────────────────────────────────────┘   │
│                         ▲                                   │
│                         │ (Deployed independently)          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Application Extensions (sysext)                     │   │
│  │  └─ Custom binaries, libraries, services            │   │
│  └──────────────────────────────────────────────────────┘   │
│                         ▲                                   │
│                         │ (Deployed independently)          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Immutable OS Layer (Read-Only)                      │   │
│  │  ├─ SquashFS root filesystem                        │   │
│  │  ├─ systemd 258+                                    │   │
│  │  ├─ Core utilities + drivers                        │   │
│  │  └─ A/B slots for atomic updates                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                         ▲                                   │
│                         │ (Swappable slots)                 │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Persistent State (/var)                             │   │
│  │  └─ Survives reboots & OS updates (ext4)            │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Runtime Mount Model

```
┌─────────────────────────────┐
│ Immutable SquashFS (RO)    │  A/B slots
│ /usr, /etc, /opt, /lib     │  Read-only at boot
└────────────────┬────────────┘
                 ▼
┌─────────────────────────────┐
│ Composable Overlays         │  systemd-sysext
│ /opt + /usr merges          │  systemd-confext
└────────────────┬────────────┘
                 ▼
┌─────────────────────────────┐
│ Persistent + Volatile       │  
│ /var (ext4, persists)       │  /run, /tmp (tmpfs)
│ /var/lib/extensions         │  Cleared on shutdown
└─────────────────────────────┘
```

### Partition Layout

```
Offset     Size         Partition              Type
────────────────────────────────────────────────────────
0          4 MiB        MBR/GPT                —
4 MiB      8 MiB        Boot (kernel/dtb)     FAT
12 MiB     500 MiB      Rootfs Slot A          SquashFS
512 MiB    500 MiB      Rootfs Slot B          SquashFS
1 GiB      (remainder)  Persistent (/var)     ext4
```

---

## Demo

### Quickstart: Build & Flash

```bash
# Clone
git clone https://github.com/ahmed-chrif/Edge-OS.git
cd Edge-OS
git checkout dev

# Initialize build environment
source ./kas-docker.sh

# Build for Jetson Orin Nano (2-4 hours, first build)
kas build kas/jetson-orin-nano.yml

# Output
ls -lh build/tmp/deploy/images/jetson-orin-nano/
# core-image-minimal.squashfs (< 200 MiB)
# core-image-minimal.wic.bz2  (full disk image)
```

### Flash to Device

```bash
# Identify device
lsblk

# Flash disk image
sudo ./scripts/flash.sh \
  build/tmp/deploy/images/jetson-orin-nano/core-image-minimal.wic.bz2 \
  /dev/sdb

sync && sudo eject /dev/sdb
# Insert into Jetson, power on
```

### Verify Boot

```bash
# Monitor serial console
picocom /dev/ttyUSB0 -b 115200

# After boot, check key properties
root@edge-os:~# mount | grep squashfs
/dev/mapper/root on / type squashfs (ro,...)

root@edge-os:~# mount | grep /var
/dev/mmcblk0p4 on /var type ext4 (rw,...)

root@edge-os:~# fw_printenv active_slot
active_slot=A

root@edge-os:~# ls -la /var/lib/extensions/
# Ready for custom extensions
```

### Deploy a Custom Extension (No Rebuild)

```bash
# On build host: create extension
cat > myapp_1.0.bb << 'EOF'
inherit sysext-image
IMAGE_INSTALL = "myapp"
EOF

# On device: deploy
scp myapp.sysext.raw root@device:/var/lib/extensions/
ssh root@device

# On device: activate
systemctl restart systemd-sysext
systemctl start myapp

# Verify persistence
touch /var/lib/myapp/startup.marker
reboot
# After reboot:
ls /var/lib/myapp/startup.marker  # ✅ Still exists
```

---

## Technologies

### Core Stack

| Component | Purpose | Version |
|-----------|---------|---------|
| **Yocto/BitBake** | Reproducible embedded Linux builds | nanbield-4.0 |
| **KAS** | Layer composition & build orchestration | Latest |
| **systemd** | Init system, sysext/confext support | 258+ |
| **SquashFS** | Immutable root filesystem | Latest |
| **U-Boot** | Bootloader with A/B slot management | Latest |
| **SWUpdate** | OTA update framework | Integrated |
| **ext4** | Persistent /var partition | Standard |

### Architecture Highlights

- **Immutable OS**: Read-only SquashFS root prevents corruption
- **A/B Deployment**: Two rootfs slots enable atomic swaps with rollback
- **Extension-Based**: Applications & configs deployed as systemd extensions (no OS rebuild)
- **Deterministic Builds**: Locked Yocto versions + layered configuration = reproducible outputs
- **Persistent State**: /var partition survives OS updates and reboots
- **Independent Lifecycles**: OS, apps, and configs updated separately

### Hardware Support

**Primary Platform**: NVIDIA Jetson Orin Nano
- ARM64 (Cortex-A78 cores)
- 8GB LPDDR5 memory
- 128GB eMMC storage
- Linux kernel 6.1+

**Extensible**: Architecture supports additional platforms via machine definitions

---

## OTA & Rollback

### A/B Update Flow

```
Current State:        Slot A (Active)
                           │
                           ▼
Write Phase:          Write new rootfs to Slot B
                      (No interruption to running system)
                           │
                           ▼
Verify Phase:         Checksum validation
                           │
                           ▼
Atomic Swap:          Update bootloader slot pointer
                      (Single, atomic operation)
                           │
                           ▼
Next Boot:            Slot B (New version)
                      Slot A (Previous version, fallback)
```

### Automatic Rollback

```bash
# If update corrupts Slot B (boot fails N times):
# U-Boot boot counter exceeds threshold
# → Automatically select Slot A
# → System boots from previous version
# → User sees no change (transparent rollback)
```

### Manual Rollback

```bash
# On device: switch to Slot A
fw_setenv active_slot A
reboot

# Verify
fw_printenv active_slot  # Should be "A"
```

### Persistent Data Preservation

```
Slot A (Old OS)  ──┐
                   │
Slot B (New OS)  ──┤  ─→  /var (Shared, Unchanged)
                   │
                   ├─→  Application state preserved
                   ├─→  Extension data preserved
                   └─→  Logs preserved
```

### Extension Updates (No OS Rebuild)

```bash
# Update application without touching OS:
scp new-myapp.sysext.raw root@device:/var/lib/extensions/
ssh root@device "systemctl restart systemd-sysext"

# Application updated, OS unchanged
# Previous extension still available for rollback
```

---

## Build Instructions

### Prerequisites

- **Build Host**: Ubuntu 20.04+ LTS
- **Disk Space**: 50 GB free (build artifacts)
- **RAM**: 8 GB minimum (16+ recommended)
- **Yocto Knowledge**: Basic BitBake familiarity (or willingness to learn)

### Step 1: Clone Repository

```bash
git clone https://github.com/ahmed-chrif/Edge-OS.git
cd Edge-OS
git checkout dev
```

### Step 2: Initialize Build Environment

```bash
# Docker-based build (recommended)
source ./kas-docker.sh

# Verify environment
kas --help
```

### Step 3: Build for Target Platform

```bash
# Jetson Orin Nano
kas build kas/jetson-orin-nano.yml

# Output artifacts
ls -lh build/tmp/deploy/images/jetson-orin-nano/
```

### Step 4: Customize (Optional)

#### Add Custom Application Layer

```bash
# Create your layer
mkdir -p meta-myapp/recipes-apps/myapp
cd meta-myapp

# Create recipe
cat > recipes-apps/myapp/myapp_1.0.bb << 'EOF'
DESCRIPTION = "My Custom Application"
LICENSE = "MIT"
SRC_URI = "git://github.com/myorg/myapp.git;branch=main"

inherit cmake

do_install() {
    install -D -m 0755 ${B}/myapp ${D}/${bindir}/myapp
}
EOF

# Add to kas configuration
# kas/jetson-orin-nano.yml:
#   repos:
#     meta-myapp:
#       path: path/to/meta-myapp
```

#### Configure Build Options

Edit `kas/jetson-orin-nano.yml`:

```yaml
local_conf_header:
  standard: |
    # Enable extensions
    ENABLE_SYSEXT ?= "1"
    ENABLE_CONFEXT ?= "1"
    
    # Compression
    SQUASHFS_COMPRESSION ?= "lz4"
    
    # Image formats
    IMAGE_FSTYPES = "squashfs"
```

### Step 5: Flash & Test

```bash
# Identify device
lsblk

# Flash
sudo ./scripts/flash.sh \
  build/tmp/deploy/images/jetson-orin-nano/core-image-minimal.wic.bz2 \
  /dev/sdb

# Eject and boot Jetson
sync && sudo eject /dev/sdb
```

### Step 6: Develop with Extensions (Iterative)

```bash
# Build your application locally
git clone git@github.com:myorg/myapp.git
cd myapp && make

# Generate sysext
./scripts/generate-sysext.sh myapp build/

# Deploy to device (no OS rebuild!)
scp myapp.sysext.raw root@device:/var/lib/extensions/
ssh root@device "systemd-sysext apply"

# Service starts immediately, no reboot needed
systemctl start myapp
```

---

## Project Structure

```
Edge-OS/
├── meta-yfs/                  # Core Edge-OS layer
│   ├── classes/               # sysext-image, confext-image, read-only-fs
│   ├── recipes-apps/          # Example applications
│   └── recipes-yfs/
│       └── images/            # Image recipes & OTA bundles
│
├── meta-yfs-bsp/              # NVIDIA Jetson BSP
│   ├── recipes-bsp/           # Storage layout, A/B rootfs
│   └── dynamic-layers/        # SWUpdate integration
│
├── meta-yfs-distro/           # Distribution policy
│   └── recipes-core/          # systemd, bootloader configs
│
├── kas/                       # Reproducible build config
│   ├── jetson-orin-nano.yml   # Jetson target
│   ├── include/               # Layers, machines, configs
│   └── overrides/
│
└── docker/                    # Reproducible build environment
```

### Layer Responsibilities

| Layer | Purpose |
|-------|---------|
| `meta-yfs` | Core architecture: immutable FS, sysext/confext, app images |
| `meta-yfs-bsp` | Jetson integration: storage layout, A/B rootfs, SSH, SWUpdate |
| `meta-yfs-distro` | Policy: systemd, bootloader, required backports |
| `kas/` | Build composition: machines, layers, dev/prod configs |
| `docker/` | Reproducible build container |

---

## Key Features

✅ **Immutable Root Filesystem**  
Read-only SquashFS prevents configuration drift and runtime corruption.

✅ **A/B Atomic Updates**  
Two rootfs slots enable zero-downtime updates with automatic rollback.

✅ **Independent Lifecycles**  
OS, applications, and configurations updated separately—no full rebuild needed.

✅ **Extension-Based Customization**  
Deploy sysext/confext without modifying the immutable OS.

✅ **Persistent State Management**  
/var partition survives OS updates and reboots.

✅ **Deterministic Builds**  
Locked Yocto versions + layered KAS config = reproducible outputs.

✅ **Production-Validated**  
Verified on NVIDIA Jetson Orin Nano.

✅ **OTA Framework**  
SWUpdate integration for secure, managed deployments.

---

## Deployment Lifecycle

```
Phase 1: Initial Deployment
  └─ Flash disk image to device
     └─ System boots from Slot A
     └─ /var initialized and mounted

Phase 2: OS Updates (A/B)
  └─ SWUpdate writes new rootfs to Slot B
     └─ Verify checksums
     └─ Atomic slot switch
     └─ Reboot to Slot B
     └─ /var persists (unchanged)

Phase 3: Application Updates (No OS Rebuild)
  └─ Deploy sysext to /var/lib/extensions/
     └─ systemd-sysext applies at runtime
     └─ Service starts (no reboot)
     └─ Persists across OS updates

Phase 4: Configuration Updates (No OS Rebuild)
  └─ Deploy confext to /var/lib/extensions/
     └─ systemd-confext applies at runtime
     └─ Config overlays active (no reboot)

Phase 5: Rollback (On Failure)
  └─ Automatic: Boot counter exceeded → Slot A
     └─ Transparent to user, data intact
  └─ Manual: fw_setenv active_slot A && reboot
     └─ Switch to previous OS version on demand
```

---

## Future Roadmap

### Phase 1: Security
- [ ] dm-verity for rootfs integrity verification
- [ ] Image signing & signature validation
- [ ] Secure boot integration (UEFI/Trusted Boot)
- [ ] TPM 2.0 support

### Phase 2: Advanced Updates
- [ ] zchunk-based delta transfer (bandwidth optimization)
- [ ] Peer-to-peer update distribution
- [ ] Graduated rollout policies
- [ ] Atomic multi-extension updates

### Phase 3: Runtime Extensions
- [ ] Container support (systemd-nspawn)
- [ ] Additional extension types (data, plugins)
- [ ] Extension dependency management

### Phase 4: Multi-Platform
- [ ] x86-64 edge devices
- [ ] ARM RISC-V targets
- [ ] Heterogeneous compute platforms

---

## Contributing

### Development Workflow

```bash
git clone https://github.com/ahmed-chrif/Edge-OS.git
cd Edge-OS
git checkout dev

# Create feature branch
git checkout -b feature/your-feature dev

# Make changes, test
kas build kas/jetson-orin-nano.yml

# Submit PR
git push origin feature/your-feature
# Create PR against `dev` branch
```

### Guidelines

- Follow [Yocto Project Best Practices](https://www.yoctoproject.org/docs/)
- Commit messages: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- Add tests for significant changes
- Update documentation

### Report Issues

Use [GitHub Issues](https://github.com/ahmed-chrif/Edge-OS/issues) with:
- Platform & hardware details
- Build host info (Ubuntu version, RAM)
- Reproduction steps
- Full error logs

---

## Technical References

### Standards & Specifications

- [Yocto Project](https://www.yoctoproject.org/)
- [BitBake](https://docs.yoctoproject.org/bitbake/)
- [systemd](https://systemd.io/)
- [systemd Extensions](https://systemd.io/EXTENSION_IMAGES/)
- [SquashFS](https://squashfs.sourceforge.net/)
- [A/B Updates](https://source.android.com/docs/core/ota/device_build)
- [KAS](https://kas-project.org/)

### Related Projects

- [SWUpdate](https://sbabic.github.io/swupdate/) — OTA framework
- [dm-verity](https://www.kernel.org/doc/html/latest/admin-guide/device-mapper/verity.html) — Verified filesystem
- [OpenEmbedded](https://www.openembedded.org/) — Community layer ecosystem

---

## License

MIT License. See [LICENSE](LICENSE) file for details.

Commercial support available through [Focus Corporation - Embedded Systems Division](https://focus.com.tn).

---

## Support & Contact

- **GitHub Issues**: [Report bugs & features](https://github.com/ahmed-chrif/Edge-OS/issues)
- **Documentation**: See `docs/` folder for detailed guides
- **Commercial Support**: [Focus Corporation](https://focus.com.tn)

---

**Built with production-grade embedded systems engineering**  
Immutable • Deterministic • Extensible • Maintainable

Last Updated: September 2026
