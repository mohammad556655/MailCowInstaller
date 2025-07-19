#!/bin/bash

set -e
if [ ! -d "/opt/mailcow-dockerized" ]; then
    # Optional: Update & install dependencies
    echo "[+] Installing dependencies..."
    curl -sSL https://get.docker.com/ | CHANNEL=stable sh
    systemctl enable --now docker
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
    
    CONF_FILE="mailcow.conf"
    HTTP_PORT=8080
    HTTP_BIND="127.0.0.1"
    HTTPS_PORT=8443
    HTTPS_BIND="127.0.0.1"
    if [ ! -f "$CONF_FILE" ]; then
        echo "mailcow.conf not found, creating a new one..."
    else
        # Update HTTP values
        if grep -q "^HTTP_PORT=" "$CONF_FILE"; then
            sed -i "s/^HTTP_PORT=.*/HTTP_PORT=${HTTP_PORT}/" "$CONF_FILE"
        fi
        if grep -q "^HTTP_BIND=" "$CONF_FILE"; then
            sed -i "s/^HTTP_BIND=.*/HTTP_BIND=${HTTP_BIND}/" "$CONF_FILE"
        fi
        
        # Update HTTPS Values
        if grep -q "^HTTPS_PORT=" "$CONF_FILE"; then
            sed -i "s/^HTTPS_PORT=.*/HTTPS_PORT=${HTTPS_PORT}/" "$CONF_FILE"
        
        fi
        if grep -q "^HTTPS_BIND=" "$CONF_FILE"; then
            sed -i "s/^HTTPS_BIND=.*/HTTPS_BIND=${HTTPS_BIND}/" "$CONF_FILE"
        fi  
    fi

    cd /opt/mailcow-dockerized

    echo "[+] Pulling Docker images..."
    docker compose pull

    echo "[+] Starting Mailcow..."
    docker compose up -d

    echo "[✓] Mailcow installed and started successfully."



    # Install Nginx if not already installed
    if ! command -v nginx &> /dev/null; then
    echo "[+] Installing Nginx..."
    apt update && apt install nginx -y
    else
    echo "[✓] Nginx already installed."
    fi

    # Set domain
    read -p "Enter your domain (e.g., mail.example.com): " DOMAIN
    CONF_PATH="/etc/nginx/sites-available/$DOMAIN"
    SSL_CERT="/opt/mailcow-dockerized/data/assets/ssl/cert.pem"
    SSL_KEY="/opt/mailcow-dockerized/data/assets/ssl/key.pem"

    # Create Nginx config
    echo "[+] Creating Nginx config for $DOMAIN..."
    cat > "$CONF_PATH" <<EOF
    server {
    listen 80 ;
    listen [::]:80 ;
    server_name $DOMAIN autodiscover.* autoconfig.*;
    return 301 https://\$host\$request_uri;
    }

    server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN autodiscover.* autoconfig.*;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!MD5:!SHA1:!kRSA;
    ssl_prefer_server_ciphers off;

    location /Microsoft-Server-ActiveSync {
        proxy_pass http://127.0.0.1:8080/Microsoft-Server-ActiveSync;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 75;
        proxy_send_timeout 3650;
        proxy_read_timeout 3650;
        proxy_buffers 64 512k;
        client_body_buffer_size 512k;
        client_max_body_size 0;
    }

    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 0;
        proxy_buffer_size 128k;
        proxy_buffers 64 512k;
        proxy_busy_buffers_size 512k;
    }
    }
    EOF

    # Enable the site by symlinking to sites-enabled
    ln -sf "$CONF_PATH" /etc/nginx/sites-enabled/

    # Test and reload Nginx
    echo "[+] Testing Nginx config..."
    nginx -t

    echo "[+] Reloading Nginx..."
    systemctl reload nginx

    echo "[✓] Nginx is configured and reloaded."
fi