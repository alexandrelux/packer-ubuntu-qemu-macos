#!/bin/bash
# Post-installation Kiosk Ubuntu 24.04

set -e

# Mode non-interactif pour éviter les prompts debconf
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIOSK_USER="ubuntu"
ROOTFS_DIR="${ROOTFS_DIR:-/tmp/kiosk-rootfs}"

echo "[postinstall] Dépendances de base..."
apt-get -yq update
apt-get -yq install ca-certificates curl gnupg rsync software-properties-common

echo "[postinstall] Installation dépôt Google Chrome..."
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-linux-signing-key.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-signing-key.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get -yq update
apt-get -yq install google-chrome-stable

echo "[postinstall] Installation et activation Cockpit..."
# S'assurer que le dépôt universe est activé (nécessaire pour cockpit)
add-apt-repository -y universe || true
apt-get -yq update
apt-get -yq install cockpit
systemctl enable --now cockpit.socket

echo "[postinstall] Installation File Browser..."
# Installation via script officiel (binaire statique dans /usr/local/bin/filebrowser)
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

FB_HOME="/home/${KIOSK_USER}/.filebrowser"
FB_DB="${FB_HOME}/filebrowser.db"
FB_ADMIN_USER="ubuntu"
FB_ADMIN_PASSWORD="ubuntu123456"
install -d -m 0755 -o "$KIOSK_USER" -g "$KIOSK_USER" "$FB_HOME"

# Initialisation de la base + compte admin au premier passage
# Note: File Browser impose un mot de passe minimum de 12 caractères.
if [ ! -f "$FB_DB" ]; then
    sudo -u "$KIOSK_USER" /usr/local/bin/filebrowser -d "$FB_DB" config init
    sudo -u "$KIOSK_USER" /usr/local/bin/filebrowser -d "$FB_DB" users add "$FB_ADMIN_USER" "$FB_ADMIN_PASSWORD" --perm.admin --hideDotfiles
fi

# Masquer les fichiers/dossiers cachés (.dotfiles) via la config interne filebrowser.
# Selon la version, le booléen peut être accepté avec ou sans "=true".
sudo -u "$KIOSK_USER" /usr/local/bin/filebrowser -d "$FB_DB" config set --hideDotfiles 2>/dev/null || \
sudo -u "$KIOSK_USER" /usr/local/bin/filebrowser -d "$FB_DB" config set --hideDotfiles=true 2>/dev/null || true

echo "[postinstall] Installation environnement graphique (X11, LightDM, i3)..."
apt-get -yq install xorg lightdm i3-wm i3status x11-xkb-utils \
    xserver-xorg-video-all \
    xfonts-base xfonts-75dpi xfonts-100dpi \
    fonts-dejavu-core \
    dbus-x11 \
    at-spi2-core

echo "[postinstall] Application du rootfs miroir..."
if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Erreur: ROOTFS_DIR introuvable: $ROOTFS_DIR"
    echo "Astuce: provisionner le dossier 'rootfs' vers /tmp/kiosk-rootfs"
    exit 1
fi

# On copie en root (sans préserver owner/group du dossier source, car le file provisioner
# transfère souvent avec l'UID/GID du user ssh). En root, les fichiers système seront donc root:root.
rsync -a --no-owner --no-group "$ROOTFS_DIR"/ /

echo "[postinstall] Ajustement des permissions utilisateur..."
USER_HOME=$(getent passwd "$KIOSK_USER" | cut -d: -f6)
install -d -m 0755 -o "$KIOSK_USER" -g "$KIOSK_USER" "$USER_HOME/.config" "$USER_HOME/.cache"
install -d -m 0755 -o "$KIOSK_USER" -g "$KIOSK_USER" "$USER_HOME/.config/google-chrome" "$USER_HOME/.config/google-chrome/Crashpad" "$USER_HOME/.config/google-chrome-kiosk"

# S'assurer que le script i3 kiosk est exécutable (au cas où)
if [ -f "$USER_HOME/.config/i3/kiosk-start.sh" ]; then
    chmod +x "$USER_HOME/.config/i3/kiosk-start.sh" || true
    chown "$KIOSK_USER:$KIOSK_USER" "$USER_HOME/.config/i3/kiosk-start.sh" || true
fi

chown -R "$KIOSK_USER:$KIOSK_USER" "$USER_HOME/.config/i3" 2>/dev/null || true
chown -R "$KIOSK_USER:$KIOSK_USER" "$FB_HOME" 2>/dev/null || true
chown -R "$KIOSK_USER:$KIOSK_USER" "$USER_HOME/.config/chrome-launchpad-extension" 2>/dev/null || true
chown "$KIOSK_USER:$KIOSK_USER" "$USER_HOME/launchpad.html" 2>/dev/null || true

echo "[postinstall] Activation des services..."
systemctl daemon-reload
systemctl enable --now filebrowser.service

# Activer LightDM pour démarrer au boot + démarrage en mode graphique
systemctl enable lightdm
systemctl set-default graphical.target

echo "[postinstall] Terminé."
exit 0
