#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# tinc vpn - installation script for Proxmox, Debian, CentOS and RedHat based servers
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################

# Default Configuration Options
vpn_ip_last=1
vpn_connect_to=""
vpn_port=655
my_default_v4ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '192.168.' | grep -v '10.0.' | grep -v '10.10.' | grep -v '127.0.0.' | tail -n 1)
reset="no"
uninstall="no"

# Parse command line options
while getopts i:p:c:a:rh:uh option
do
  case "${option}"
      in
    i) vpn_ip_last=${OPTARG} ;;
    p) vpn_port=${OPTARG} ;;
    c) vpn_connect_to=${OPTARG} ;;
    a) my_default_v4ip=${OPTARG} ;;
    r) reset="yes" ;;
    u) uninstall="yes" ;;
    *) echo "-i <last_ip_part 10.10.1.?> -p <vpn port if not 655> -c <vpn host to connect to, eg. prx_b> -a <public ip address, or will auto-detect> -r (reset) -u (uninstall)" ; exit ;;
  esac
done

# Reset or Uninstall TincVPN
if [ "$reset" == "yes" ] || [ "$uninstall" == "yes" ] ; then
  echo "Stopping Tinc"
  systemctl stop tinc-xsvpn.service
  pkill -9 tincd

  echo "Removing configs"
  rm -rf /etc/tinc/my_default_v4ip
  rm -rf /etc/tinc/xsvpn
  mv -f /etc/tinc/nets.boot.orig /etc/tinc/nets.boot
  rm -f /etc/network/interfaces.d/tinc-vpn.cfg
  rm -f /etc/systemd/system/tinc-xsvpn.service

  if [ "$uninstall" == "yes" ] ; then
    systemctl disable tinc.service
    echo "Tinc uninstalled"
    exit 0
  fi
fi

# Install Tinc if not installed
if ! command -v tinc &> /dev/null ; then
  if command -v apt-get &> /dev/null ; then
    echo "Installing Tinc..."
    DEBIAN_FRONTEND=noninteractive apt-get -y install tinc
  else
    echo "ERROR: Tinc could not be installed"
    exit 1
  fi
fi

# Auto-detect the default IPv4 address if not provided
if [ "$my_default_v4ip" == "" ] ; then
  default_interface="$(ip route | awk '/default/ { print $5 }' | grep -v "vmbr")"
  if [ "$default_interface" == "" ]; then
    default_interface="$(ip link | sed -e '/state DOWN / { N; d; }' | sed -e '/veth[0-9].*:/ { N; d; }' | sed -e '/vmbr[0-9].*:/ { N; d; }' | sed -e '/lo:/ { N; d; }' | head -n 1 | cut -d':' -f 2 | xargs)"
  fi
  if [ "$default_interface" == "" ]; then
    echo "ERROR: Could not detect default interface"
    exit 1
  fi
  default_v4="$(ip -4 addr show dev "$default_interface" | awk '/inet/ { print $2 }')"
  my_default_v4ip=${default_v4%/*}
  if [ "$my_default_v4ip" == "" ] ; then
    echo "ERROR: Could not detect default IPv4 address"
    exit 1
  fi
fi

# Assign and validate variables
my_name=$(uname -n)
my_name=${my_name//-/_}

if [[ "$vpn_connect_to" == *"-"* ]]; then
  echo "ERROR: '-' character is not allowed in hostname for vpn_connect_to"
  exit 1
fi

echo "Options:"
echo "VPN IP: 10.10.1.${vpn_ip_last}"
echo "VPN PORT: ${vpn_port}"
echo "VPN Connect to host: ${vpn_connect_to}"
echo "Public Address: ${my_default_v4ip}"

# Generate RSA keys if not present
mkdir -p /etc/tinc/xsvpn/hosts
if [ ! -f /etc/tinc/xsvpn/rsa_key.priv ]; then
  echo "Generating new 4096-bit RSA keys..."
  tincd -K4096 -c /etc/tinc/xsvpn <<<y &> /dev/null
fi

# Generate TincVPN configuration
cat <<EOF > /etc/tinc/xsvpn/tinc.conf
Name = $my_name
AddressFamily = ipv4
Interface = Tun0
Mode = switch
ConnectTo = $vpn_connect_to
EOF

cat <<EOF > "/etc/tinc/xsvpn/hosts/$my_name"
Address = ${my_default_v4ip}
Subnet = 10.10.1.${vpn_ip_last}
Port = ${vpn_port}
Compression = 10 #LZO
EOF
cat /etc/tinc/xsvpn/rsa_key.pub >> "/etc/tinc/xsvpn/hosts/${my_name}"

# Create Tinc-up and Tinc-down scripts
cat <<EOF > /etc/tinc/xsvpn/tinc-up
#!/usr/bin/env bash
ip link set \$INTERFACE up
ip addr add 10.10.1.${vpn_ip_last}/24 dev \$INTERFACE
ip route add 10.10.1.0/24 dev \$INTERFACE

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set a multicast route over interface
route add -net 224.0.0.0 netmask 240.0.0.0 dev \$INTERFACE
EOF
chmod 755 /etc/tinc/xsvpn/tinc-up

cat <<EOF > /etc/tinc/xsvpn/tinc-down
#!/usr/bin/env bash
ip route del 10.10.1.0/24 dev \$INTERFACE
ip addr del 10.10.1.${vpn_ip_last}/24 dev \$INTERFACE
ip link set \$INTERFACE down

# Disable IP forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward
EOF
chmod 755 /etc/tinc/xsvpn/tinc-down

# Create Systemd service
cat <<EOF > /etc/systemd/system/tinc-xsvpn.service
[Unit]
Description=eXtremeSHOK.com Tinc VPN
After=network.target

[Service]
Type=simple
WorkingDirectory=/etc/tinc/xsvpn
ExecStart=$(command -v tincd) -n xsvpn -D -d2
ExecReload=$(command -v tincd) -n xsvpn -kHUP
TimeoutStopSec=5
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# Enable TincVPN at boot
systemctl enable tinc-xsvpn.service

# Add a Tun0 entry to /etc/network/interfaces for VPN
mkdir -p /etc/network/interfaces.d/
cat <<EOF > /etc/network/interfaces.d/tinc-vpn.cfg
# Tinc VPN
iface Tun0 inet static
  address 10.10.1.${vpn_ip_last}
  netmask 255.255.255.0
  broadcast 0.0.0.0
EOF

# Display instructions for adding other VPN nodes
echo ""
echo "Run the following on the other VPN nodes:"
echo "The following information is stored in /etc/tinc/xsvpn/this_host.info"

echo 'cat <<EOF >> /etc/tinc/xsvpn/hosts/'"${my_name}" > /etc/tinc/xsvpn/this_host.info
cat "/etc/tinc/xsvpn/hosts/${my_name}" >> /etc/tinc/xsvpn/this_host.info
echo "EOF" >> /etc/tinc/xsvpn/this_host.info

echo ""
echo 'cat <<EOF >> /etc/tinc/xsvpn/hosts/'"${my_name}"
cat "/etc/tinc/xsvpn/hosts/${my_name}"
echo "EOF"
echo ""
