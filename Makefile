.PHONY: all help h
all: clean build/cidata.iso build/packer-ubuntu-24.04-amd64 ## Build the complete Ubuntu image using Packer

.PHONY: clean
clean: ## Clean build artifacts
	rm -rf build

build/cidata.iso: cidata/meta-data cidata/user-data
	mkdir -p build
	rm -rf build/cidata.iso
	hdiutil makehybrid -o build/cidata.iso cidata -iso -joliet

build/packer-ubuntu-24.04-amd64: ubuntu-qemu-macos.pkr.hcl build/cidata.iso
	mkdir -p build
	rm -rf build/packer-ubuntu-24.04-amd64
	packer build ubuntu-qemu-macos.pkr.hcl

QEMU_DISK := build/packer-ubuntu-24.04-amd64/packer-ubuntu-24.04-amd64
.PHONY: run
run: ## Launch the VM with QEMU (requires 'make all' first)
	qemu-system-x86_64 \
	 -machine q35,accel=tcg \
	 -cpu qemu64 \
	 -smp 4 \
	 -m 4096 \
	 -drive file=$(QEMU_DISK),format=qcow2 \
	 -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::9090-:9090,hostfwd=tcp::8080-:8080 \
	 -device virtio-net,netdev=net0 \
	 -vga none \
	 -device virtio-vga,xres=1280,yres=768 \
	 -display default,show-cursor=on \
	 -k fr \
	 -usb -device usb-tablet

help h: ## Display this help message
	@echo "Available targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[^#\t@].*:.*?## / && !/grep|sed|awk|echo/ {printf "  %-30s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
	@echo ""
	@echo "Usage: make [target]"
