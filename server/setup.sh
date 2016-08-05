#!/bin/bash
#
# DO-AutoVPN Droplet Setup Script
# By Chris Blake (chrisrblake93@gmail.com)
#

# Are we root?
if [[ $EUID -ne 0 ]]; then
  echo "You must be a root user" 1>&2
  exit 1
fi

# Set our env settings (these are randomly sent to us vi the meta info)
HTTPS_PORT=$1
AUTH_USER=$2
AUTH_PASS=$3
REMOVE_TIMEOUT=$4
DO_APIKEY=$5
SERVER_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
OVPN_DIR="/etc/openvpn"

# Save our key to a file for later usage (to remove self)
echo $DO_APIKEY > /root/.do_apikey

# Setup apt-get rules for configuring
debconf-set-selections <<EOF
iptables-persistent iptables-persistent/autosave_v4 boolean true
iptables-persistent iptables-persistent/autosave_v6 boolean true
EOF

# Install required packages
apt-get install -qy fail2ban python python-openssl openvpn curl iptables-persistent

# Setup key for Python Client
openssl req -new -x509 -keyout py-server.pem -out py-server.pem -days 365 -subj /CN=$SERVER_IP/ -nodes

# Certificate Authority
>$OVPN_DIR/ca-key.pem      openssl genrsa 2048
>$OVPN_DIR/ca-csr.pem      openssl req -new -key $OVPN_DIR/ca-key.pem -subj /CN=OpenVPN-CA/
>$OVPN_DIR/ca-cert.pem     openssl x509 -req -in $OVPN_DIR/ca-csr.pem -signkey $OVPN_DIR/ca-key.pem -days 365
>$OVPN_DIR/ca-cert.srl     echo 01

# Server Key & Certificate
>$OVPN_DIR/server-key.pem  openssl genrsa 2048
>$OVPN_DIR/server-csr.pem  openssl req -new -key $OVPN_DIR/server-key.pem -subj /CN=OpenVPN-Server/
>$OVPN_DIR/server-cert.pem openssl x509 -req -in $OVPN_DIR/server-csr.pem -CA $OVPN_DIR/ca-cert.pem -CAkey $OVPN_DIR/ca-key.pem -days 365

# Client Key & Certificate
>$OVPN_DIR/client-key.pem  openssl genrsa 2048
>$OVPN_DIR/client-csr.pem  openssl req -new -key $OVPN_DIR/client-key.pem -subj /CN=OpenVPN-Client/
>$OVPN_DIR/client-cert.pem openssl x509 -req -in $OVPN_DIR/client-csr.pem -CA $OVPN_DIR/ca-cert.pem -CAkey $OVPN_DIR/ca-key.pem -days 365

# Diffie hellman parameters
>$OVPN_DIR/dh.pem     openssl dhparam 2048

# Set Permissions
chmod 600 $OVPN_DIR/*-key.pem

# Set up IP forwarding and NAT for iptables
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
sysctl -p

# Configure and save iptables in case of reboots
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport $HTTPS_PORT -j ACCEPT
iptables -P INPUT DROP
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables-save > /etc/iptables/rules.v4

# Write configuration files for client and server
>$OVPN_DIR/server-443.conf cat <<EOF
server      10.8.0.0 255.255.255.0
verb        3
duplicate-cn
key         server-key.pem
ca          ca-cert.pem
cert        server-cert.pem
dh          dh.pem
keepalive   10 120
persist-key yes
persist-tun yes
comp-lzo    yes
push        "dhcp-option DNS 8.8.8.8"
push        "dhcp-option DNS 8.8.4.4"

# Enable management so we can watch local connected clients
# management localhost 7505

# Normally, the following command is sufficient.
# However, it doesn't assign a gateway when using
# VMware guest-only networking.
#
# push        "redirect-gateway def1 bypass-dhcp"

push        "redirect-gateway bypass-dhcp"
push        "route-metric 512"
push        "route 0.0.0.0 0.0.0.0"

user        nobody
group       nogroup

proto       tcp
port        443
dev         tun443
status      openvpn-status-443.log
EOF

>$OVPN_DIR/client.ovpn cat <<EOF
client
nobind
dev tun
redirect-gateway def1 bypass-dhcp
remote $SERVER_IP 443 tcp
comp-lzo yes

<key>
$(cat $OVPN_DIR/client-key.pem)
</key>
<cert>
$(cat $OVPN_DIR/client-cert.pem)
</cert>
<ca>
$(cat $OVPN_DIR/ca-cert.pem)
</ca>
EOF

# Copy over the client config
cp $OVPN_DIR/client.ovpn ./client.ovpn

# Startup the self destruct script
mv ./remove-instance.sh /usr/bin/remove-instance.sh && chmod +x /usr/bin/remove-instance.sh
/usr/bin/remove-instance.sh $REMOVE_TIMEOUT &

# Configure OpenVPN and start it
sed -ie '0,/#AUTOSTART/ s/#AUTOSTART/AUTOSTART/' /etc/default/openvpn
systemctl daemon-reload
service openvpn restart

# Serve up the HTTPS server so the config can be pulled
./handoff-server.py $HTTPS_PORT $AUTH_USER:$AUTH_PASS

# If we make it here, we are done. remove port from firewall and save
iptables -D INPUT -p tcp --dport $HTTPS_PORT -j ACCEPT
iptables-save > /etc/iptables/rules.v4

# Finish
echo "setup.sh Complete!"
