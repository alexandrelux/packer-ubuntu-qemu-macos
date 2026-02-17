variable "vm_name" {
  type = string
  default = "packer-ubuntu-24.04-amd64"
}

variable "iso_url" {
  type = string
  default = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "iso_checksum" {
  type = string
  default = "file:https://cloud-images.ubuntu.com/releases/noble/release/SHA256SUMS"
}

# qemu-system-x86_64
source "qemu" "macos" {
  vm_name = var.vm_name
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  disk_image = true
  format = "qcow2"
  output_directory = "build/${var.vm_name}"
  machine_type = "q35"
  accelerator = "tcg"
  cpus = 4
  memory = "4096"
  headless = true
  ssh_port = 22
  ssh_username = "ubuntu"
  ssh_password = "ubuntu123456"
  ssh_wait_timeout = "300s"
  qemuargs = [
    ["-cdrom", "build/cidata.iso"]
  ]
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
}

build {
  name = "macos"
  source "qemu.macos" {
  }

  provisioner "file" {
    source      = "scripts"
    destination = "/tmp/kiosk-scripts"
  }

  provisioner "file" {
    source      = "rootfs"
    destination = "/tmp/kiosk-rootfs"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/kiosk-scripts/postinstall.sh",
      "sudo /tmp/kiosk-scripts/postinstall.sh",
      "rm -rf /tmp/kiosk-scripts /tmp/kiosk-rootfs"
    ]
  }
}
