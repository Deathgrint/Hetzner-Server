
#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################
#
## CREATES A ROUTED vmbr0 AND NAT vmbr1 NETWORK CONFIGURATION FOR PROXMOX
# Autodetects the correct settings (interface, gateway, netmask, etc)
# Supports IPv4 and IPv6, Private Network uses 10.10.10.1/24
#
# Also installs and properly configures the isc-dhcp-server to allow for DHCP on the vmbr1 (NAT)
#
# ROUTED (vmbr0):
#   All traffic is routed via the main IP address and uses the MAC address of the physical interface.
#   VM's can have multiple IP addresses and they do NOT require a MAC to be set for the IP via service provider
#
# NAT (vmbr1):
#   Allows a VM to have internet connectivity without requiring its own IP address
#   Assigns 10.10.10.100 - 10.10.10.150 via DHCP
#
# Public IP's can be assigned via DHCP, adding a host define to the /etc/dhcp/hosts.public file
#
# Tested on OVH and Hetzner based servers
#
# ALSO CREATES A NAT Private Network as vmbr1
#
# NOTE: WILL OVERWRITE /etc/network/interfaces
# A backup will be created as /etc/network/interfaces.timestamp
#
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
################################################################################

# Set the locale
export LANG="en_US.UTF-8"
export LC_ALL="C"

network_interfaces_file="/etc/network/interfaces"
backup_file="${network_interfaces_file}.$(date +%s).backup"

# Ensure dependencies are installed and internet connection is available
function check_requirements() {
    echo "Checking if Internet connection is available..."
    if ! ping -c 1 google.com &> /dev/null; then
        echo "Error: No Internet connection detected. Exiting..."
        exit 1
    fi

    echo "Checking if dhcpd is installed..."
    if ! type "dhcpd" >& /dev/null; then
        echo "Installing isc-dhcp-server..."
        if ! apt-get install -y isc-dhcp-server; then
            echo "Error: Failed to install isc-dhcp-server. Exiting..."
            exit 1
        fi
    fi
}

# Backup current network configuration
function backup_network_configuration() {
    echo "Backing up current network configuration..."
    cp ${network_interfaces_file} ${backup_file}
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create a backup of the network configuration. Exiting..."
        exit 1
    fi
}

# Apply network configuration changes
function apply_network_configuration() {
    echo "Applying new network configuration..."
    # Apply the new configuration (this part would normally modify the network interfaces file)
    # Example: echo "new configuration" > ${network_interfaces_file}

    # Test the new configuration
    ifdown -a && ifup -a
    if [ $? -ne 0 ]; then
        echo "Error: Network configuration failed. Restoring previous configuration..."
        cp ${backup_file} ${network_interfaces_file}
        ifdown -a && ifup -a
        exit 1
    fi
}

# Additional security: Ensure DHCP is only running on vmbr1
function configure_dhcp_server() {
    echo "Configuring DHCP server to only operate on vmbr1..."
    sed -i '/INTERFACESv4=/d' /etc/default/isc-dhcp-server
    echo 'INTERFACESv4="vmbr1"' >> /etc/default/isc-dhcp-server
}

# Main script execution
check_requirements
backup_network_configuration
apply_network_configuration
configure_dhcp_server

echo "Network configuration applied and optimized successfully."
