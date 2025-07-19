#!/bin/bash

set -e

# Optional: Update & install dependencies
echo "[+] Installing dependencies..."
apt update && apt install  docker-compose-plugin -y



if [ "$(umask)" == "0022" ]; then 
    echo "umask is correctly set to 0022"
else 
     echo "umask is NOT 0022, current umask: $(umask)"
fi



echo "[+] Change Directory to /opt..."
cd /opt


# Clone mailcow
echo "[+] Cloning Mailcow..."
git clone https://github.com/mailcow/mailcow-dockerized
cd mailcow-dockerized

echo "[+] Generation Configuration Files..."
./generate_config.sh
# Replace mailcow.conf with your template
echo "[+] Configuring mailcow.conf..."
CONF_FILE="mailcow.conf
HTTP_PORT=8080
HTTP_BIND="127.0.0.1"
HTTPS_PORT=8443
HTTPS_BIND="127.0.0.1"
if [ ! -f "$CONF_FILE" ]: then
    echo "mailcow.conf not found, creating a new one..."
else
    # Update HTTP values
    if grep -q "^HTTP_PORT=" "$CONF_FILE"; then
        sed -i "s/^HTTP_PORT=.*/HTTP_PORT=${HTTP_PORT}/" "$CONF_FILE"
    fi
    if grep -q "^HTTP_BIND=" "$CONF_FILE"; then
        sed -i "^HTTP_BIND=.*/HTTP_BIND=${HTTP_BIND}/" "$CONF_FILE"
    fi
    
    # Update HTTPS Values
    if grep -q "^HTTPS_PORT=" "$CONF_FILE"; then
        sed -i "s/^HTTPS_PORT=.*/HTTPS_PORT=${HTTPS_PORT}/" "$CONF_FILE"
    
    fi
    if grep -q "^HTTPS_BIND=" "$CONF_FILE"; then
        sed -i "s/^HTTPS_BIND=.*/HTTPS_BIND=${HTTPS_BIND}/" "$CONF_FILE"
    fi  
fi
# Pull images and start containers
echo "[+] Pulling Docker images..."
docker compose pull

echo "[+] Starting Mailcow..."
docker compose up -d

echo "[✓] Mailcow installed and started successfully."
