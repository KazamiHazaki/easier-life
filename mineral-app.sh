#!/usr/bin/env bash

read -p "Enter your private key: " MINING_PK

echo '================================================='
echo -e "Your PK: \e[1m\e[32m$MINING_PK\e[0m"
echo '================================================='
sleep 3

echo -e "\e[1m\e[32m1. Install Unzip \e[0m" && sleep 1
sudo apt install unzip -y

echo -e "\e[1m\e[32m1. Installing App. \e[0m" && sleep 1
mkdir mineral-app
cd $HOME/mineral-app
wget -O mining-app.zip https://github.com/ronanyeah/mineral-app/releases/download/v1/linux.zip
unzip mining-app.zip
chmod +x mineral-linux
sudo cp mineral-linux /usr/bin
sudo rm -rf mineral* 

sudo tee <<EOF >/dev/null /etc/systemd/system/mineral-app.service
[Unit]
Description=mineral-mining
After=network-online.target

[Service]
TimeoutStartSec=0
CPUWeight=95
IOWeight=95
ExecStart=mineral-linux mine
Restart=always
RestartSec=2
LimitNOFILE=800000
KillSignal=SIGTERM
Environment="WALLET=${MINING_PK}"
[Install]
WantedBy=multi-user.target
EOF

echo -e "\e[1m\e[32m1. Starting App. \e[0m" && sleep 1
sudo systemctl daemon-reload
sudo systemctl start mineral-app

echo -e "\e[1m\e[32mInstallation finished... \e[0m" && sleep 1
echo -e "\e[1m\e[32mYour app is running. Check logs with \"sudo journalctl -u mineral-app.service -f --no-hostname -o cat\"\e[0m" && sleep 1
