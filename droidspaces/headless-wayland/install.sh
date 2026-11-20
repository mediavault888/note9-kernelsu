#!/bin/sh
# Headless Wayland base for a Droidspaces Ubuntu 24.04 container.
# Run INSIDE the container as root, from this directory:  sh install.sh
# Result: sway (headless backend, pixman) + wayvnc on :5900 (TLS / RSA-AES login)
#         + noVNC browser access on https://<phone-ip>:6080 (HTTP basic auth)
set -eu
cd "$(dirname "$0")"
NOVNC_VER=1.7.0
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends sway wayvnc foot xwayland grim \
    fonts-dejavu-core openssl ca-certificates curl iproute2 dbus-user-session python3-websockify

id wl >/dev/null 2>&1 || useradd -m -u 1000 -s /bin/bash -G aid_inet,aid_net_raw,video,input wl

install -d -m 755 /etc/headless-wayland
[ -f /etc/headless-wayland/config ] || install -m 644 files/config /etc/headless-wayland/config
install -m 644 files/sway.conf /etc/headless-wayland/sway.conf
: > /etc/headless-wayland/wayvnc-local.config
install -m 755 files/session.sh /usr/local/bin/headless-wayland-session
install -m 755 files/nested files/hw-status files/hw-shot /usr/local/bin/
install -m 644 files/headless-wayland.service files/headless-wayland-web.service /etc/systemd/system/

cd /etc/headless-wayland
if [ ! -f wayvnc.config ]; then
    PW=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 12)
    openssl req -x509 -newkey rsa:2048 -nodes -keyout tls_key.pem -out tls_cert.pem -days 3650 -subj /CN=headless-wayland 2>/dev/null
    openssl genrsa -traditional -out rsa_key.pem 2048 2>/dev/null || openssl genrsa -out rsa_key.pem 2048 2>/dev/null
    cat > wayvnc.config <<EOC
enable_auth=true
username=wl
password=$PW
private_key_file=/etc/headless-wayland/tls_key.pem
certificate_file=/etc/headless-wayland/tls_cert.pem
rsa_private_key_file=/etc/headless-wayland/rsa_key.pem
EOC
    printf 'WEB_PASSWORD=%s\n' "$PW" > web.env
    echo "Generated login: user wl, password $PW  (stored in /etc/headless-wayland/wayvnc.config)"
fi
chown root:wl wayvnc.config web.env tls_key.pem rsa_key.pem
chmod 640 wayvnc.config web.env tls_key.pem rsa_key.pem

if [ ! -f /opt/novnc/vnc.html ]; then
    install -d /opt/novnc
    curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v$NOVNC_VER.tar.gz" | tar -xz -C /opt/novnc --strip-components=1
    ln -sf vnc.html /opt/novnc/index.html
fi

install -d -o wl -g wl /home/wl/.config/sway/config.d
systemctl daemon-reload
systemctl enable --now headless-wayland headless-wayland-web
sleep 5
hw-status
