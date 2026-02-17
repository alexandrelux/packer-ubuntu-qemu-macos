#!/bin/bash
# i3 kiosk start: lance Chrome et le relance si fermeture/crash.
#
# Par défaut on garde le comportement "maximisé avec UI" (onglets/barre visibles),

set -u

LAUNCHPAD_URL="file:///home/ubuntu/.config/chrome-launchpad-extension/launchpad.html"
KIOSK_URL="${KIOSK_URL:-$LAUNCHPAD_URL}"
KIOSK_MODE="${KIOSK_MODE:-maximized}" # "maximized" ou "kiosk"
CHECK_DELAY="${CHECK_DELAY:-2}"

log() {
  logger -t i3-kiosk-start "$*"
}

# Attendre que DISPLAY soit défini (LightDM/i3)
for _ in $(seq 1 200); do
  if [ -n "${DISPLAY:-}" ]; then
    break
  fi
  sleep 0.1
done

log "Démarrage (DISPLAY=${DISPLAY:-unset}) URL=$KIOSK_URL MODE=$KIOSK_MODE"

CHROME_CMD=""
if command -v google-chrome-stable >/dev/null 2>&1; then
  CHROME_CMD="google-chrome-stable"
elif command -v google-chrome >/dev/null 2>&1; then
  CHROME_CMD="google-chrome"
elif [ -x /usr/bin/google-chrome-stable ]; then
  CHROME_CMD="/usr/bin/google-chrome-stable"
fi

if [ -z "$CHROME_CMD" ]; then
  log "ERREUR: Chrome non trouvé (google-chrome-stable)"
  # On ne boucle pas inutilement si Chrome n'est pas installé
  exit 1
fi

# Répertoires de profil (évite des crashs et problèmes de permissions)
CHROME_DATA_DIR="$HOME/.config/google-chrome-kiosk"
mkdir -p "$CHROME_DATA_DIR/Default"
mkdir -p "$HOME/.config/google-chrome/Crashpad"

# Extension Chrome pour remplacer la page de nouvel onglet
EXTENSION_DIR="$HOME/.config/chrome-launchpad-extension"
EXTENSION_PATH="$EXTENSION_DIR"

COMMON_FLAGS=(
  --no-default-browser-check
  --user-data-dir="$CHROME_DATA_DIR"
  --load-extension="$EXTENSION_PATH"
)

MODE_FLAGS=()
URL_FLAGS=("$KIOSK_URL")
if [ "$KIOSK_MODE" = "kiosk" ]; then
  # Vrai mode kiosk (UI cachée). --app ouvre une fenêtre sans onglets.
  MODE_FLAGS+=(--kiosk --app="$KIOSK_URL")
  URL_FLAGS=()
else
  # Comportement proche de ton setup actuel (UI visible)
  MODE_FLAGS+=(--start-maximized)
fi

LOG_FILE="${LOG_FILE:-/tmp/chrome.log}"

while true; do
  log "Lancement Chrome: $CHROME_CMD"
  "$CHROME_CMD" "${COMMON_FLAGS[@]}" "${MODE_FLAGS[@]}" "${URL_FLAGS[@]}" >>"$LOG_FILE" 2>&1 &
  CHROME_PID=$!
  log "Chrome PID=$CHROME_PID"

  # Attendre la fin du process Chrome
  wait "$CHROME_PID"
  EXIT_CODE=$?
  log "Chrome terminé (exit=$EXIT_CODE). Relance dans ${CHECK_DELAY}s"
  sleep "$CHECK_DELAY"
done

