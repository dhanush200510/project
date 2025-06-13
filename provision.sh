#!/bin/bash

# Exit immediately if a command fails
set -e

echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

# Set versions
PROM_VERSION="2.52.0"
NODE_EXPORTER_VERSION="1.8.0"
GRAFANA_DEB="grafana_10.2.0_amd64.deb"

echo "⬇ Downloading Prometheus..."
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar -xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

echo "📦 Installing Prometheus..."
sudo mv prometheus promtool /usr/local/bin/
sudo mkdir -p /etc/prometheus
sudo cp -r consoles console_libraries /etc/prometheus
sudo cp prometheus.yml /etc/prometheus/
cd ..
rm -rf prometheus-${PROM_VERSION}.linux-amd64*

# Create Prometheus systemd service with 0.0.0.0 binding
echo "📝 Creating Prometheus service..."
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --web.listen-address=0.0.0.0:9090 \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /var/lib/prometheus
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

echo "⬇ Downloading Node Exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*

# Create Node Exporter systemd service with 0.0.0.0 binding
echo "📝 Creating Node Exporter service..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=0.0.0.0:9100

Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "⬇ Installing Grafana..."
sudo apt install -y adduser libfontconfig1
wget https://dl.grafana.com/oss/release/${GRAFANA_DEB}
sudo dpkg -i ${GRAFANA_DEB}
rm ${GRAFANA_DEB}

# Modify Grafana config to listen on all interfaces (0.0.0.0)
echo "📝 Configuring Grafana to listen on all interfaces..."
sudo sed -i 's/^;http_addr =.*/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini

echo "⚙ Enabling and starting Grafana..."
sudo systemctl enable grafana-server
sudo systemctl restart grafana-server

echo "✅ All monitoring tools installed and configured!"
echo "🌐 Access them using your server IP:"
echo "   - Prometheus:  http://<your-ip>:9090"
echo "   - Node Exporter: http://<your-ip>:9100"
echo "   - Grafana:     http://<your-ip>:3000"
