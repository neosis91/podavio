#!/usr/bin/env sh
# Compile la page Podavio Web et l’envoie sur https://web.podavio.com.
#
# Usage : tool/deploy_web.sh
#
# Prérequis : node, npm, agent SSH. Si SSH_AUTH_SOCK n’est pas défini,
# le script utilise l’agent Bitwarden (~/.bitwarden-ssh-agent.sock).
#
# --delete ne retire que les fichiers de la page, dans
# /opt/podavio-web/web/dist/web/browser/. Le site des binaires
# (/var/www/podavio-site/) n’est pas touché. Le relais n’est pas
# redémarré : les navigateurs déjà liés restent connectés.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
WEB="${ROOT}/companion/web"
HOST="${PODAVIO_WEB_HOST:-ubuntu@51.91.250.233}"
DEST="${PODAVIO_WEB_DEST:-/opt/podavio-web/web/dist/web/browser/}"

case "${DEST}" in
  *podavio-site*)
    echo "Refus : ce script ne déploie pas le site des binaires." >&2
    exit 1
    ;;
  */browser|*/browser/) ;;
  *)
    echo "Destination inattendue : ${DEST}" >&2
    exit 1
    ;;
esac

if [ -z "${SSH_AUTH_SOCK:-}" ]; then
  sock="${HOME}/.bitwarden-ssh-agent.sock"
  if [ ! -S "${sock}" ]; then
    echo "Agent SSH introuvable. Définis SSH_AUTH_SOCK." >&2
    exit 1
  fi
  export SSH_AUTH_SOCK="${sock}"
fi

cd "${WEB}"
npm run build

rsync -az --delete -e "ssh -o BatchMode=yes" \
  dist/web/browser/ \
  "${HOST}:${DEST}"

echo "Page publiée sur https://web.podavio.com"
