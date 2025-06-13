#!/bin/bash

set -e

# Update and Install Dependencies
sudo apt update
sudo apt install -y wget curl unzip software-properties-common apt-transport-https gnupg2

# Install Node Exporter
sudo useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter*

cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Install Prometheus
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir -p /etc/prometheus /var/lib/prometheus

wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar xvf prometheus-2.52.0.linux-amd64.tar.gz
cd prometheus-2.52.0.linux-amd64

sudo cp prometheus promtool /usr/local/bin/
sudo cp -r consoles console_libraries /etc/prometheus
sudo cp prometheus.yml /etc/prometheus/prometheus.yml
cd ..
rm -rf prometheus*

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.listen-address=0.0.0.0:9090 \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus

# Install Grafana
sudo apt install -y software-properties-common
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
wget -q -O - https://packages.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/grafana.gpg
sudo apt update
sudo apt install -y grafana

sudo sed -i 's/^;http_addr =.*/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini

sudo systemctl daemon-reload
sudo systemctl enable --now grafana-server

echo
echo "All services installed and running."
echo "Access using your system IP:"
echo "Prometheus:    http://<your-ip>:9090"
echo "Node Exporter: http://<your-ip>:9100"
echo "Grafana:       http://<your-ip>:3000"
