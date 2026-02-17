# Packer Ubuntu QEMU for macOS

Ubuntu 24.04 kiosk image with QEMU for macOS. Includes Chrome (starts automatically in fullscreen), Cockpit, File Browser.

## Prerequisites

- Packer
- QEMU

## Build

```bash
make clean
make all
```

## Launch

```bash
make run qemu
```

## Access

- **Cockpit**: http://localhost:9090
- **File Browser**: http://localhost:8080 (ubuntu/ubuntu123456)
- **SSH**: `ssh -p 2222 ubuntu@localhost`

## SSH Connection and X11 Configuration

```bash
ssh -p 2222 ubuntu@localhost
export DISPLAY=:0
xrandr --output Virtual-1 --mode 1280x768
```
