#!/bin/bash

# ================================
# Install Script (install.sh)
# Doel: Directus dev/prod containers + DNS-setup
# Wordt uitgevoerd door StackScript na clone van GitHub
# ================================

set -e

# === Config ===
DOMAIN=$(cat /etc/klantdomein)
PROJECT_ROOT=/srv
API_TOKEN=${LINODE_API_TOKEN:-""} # uit .env of shell export
DOMAIN_ID=${LINODE_DOMAIN_ID:-""} # ID van serverz.nl domein
DO_DNS=false

# === Argumenten parsen ===
for arg in "$@"; do
  if [ "$arg" == "--dns" ]; then
    DO_DNS=true
  fi
done

# === Functie: DNS-records toevoegen via Linode API ===
add_dns_records() {
  echo "Voeg A-records toe voor $DOMAIN via Linode API..."

  if [ -z "$API_TOKEN" ] || [ -z "$DOMAIN_ID" ]; then
    echo "API-token of domein ID ontbreekt. Sla DNS-aanmaak over."
    return
  fi

  IP=$(curl -s ifconfig.me)

  for NAME in "$HOSTNAME" "*.$HOSTNAME"; do
    echo "DNS toevoegen: $NAME → $IP"
    curl -s -X POST \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"type": "A", "name": "'"$NAME"'", "target": "'"$IP"'", "ttl_sec": 300}' \
      https://api.linode.com/v4/domains/$DOMAIN_ID/records
  done
}

# === Functie: Directus containers opzetten ===
setup_directus_env() {
  for ENV in dev prod; do
    echo "Maak $ENV omgeving aan..."
    mkdir -p $PROJECT_ROOT/$ENV/directus
    cd $PROJECT_ROOT/$ENV/directus

    echo "🔧 Genereer .env"
    cat <<EOF > .env
DOMAIN=$ENV.$DOMAIN
PORT=805${ENV: -1}  # bijv. 805d of 805p
EOF

    echo "Start docker compose ($ENV)"
    docker compose up -d || docker-compose up -d
  done
}

# === Uitvoeren ===
if [ "$DO_DNS" = true ]; then
  add_dns_records
fi

setup_directus_env

echo "Installatie afgerond. Toegang: https://prod.$DOMAIN en https://dev.$DOMAIN"
