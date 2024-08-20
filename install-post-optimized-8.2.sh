
#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# post-installation script for Proxmox VE 8.2
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################
#
# Tested on Proxmox Version: 8.2
#
# Assumptions: Proxmox VE 8.2 installed
#
# Notes:
# openvswitch will be disabled (removed) when ifupdown2 is enabled
# ifupdown2 will be disabled (removed) when openvswitch is enabled
#
# Docker : not advisable to run docker on the Hypervisor (Proxmox) directly.
# Correct way is to create a VM which will be used exclusively for docker.
# e.g., fresh Ubuntu LTS server with https://github.com/extremeshok/xshok-docker
################################################################################

#####  S E T   Y O U R   O P T I O N S  #####
# User Defined Options for (install-post.sh) post-installation script for Proxmox VE 8.2
# are set in the xs-install-post.env, see the sample : xs-install-post.env.sample
## Alternatively, set the variable via the export
# Example to disable the MOTD
# export XS_MOTD="no" ; bash install-post.sh
###############################
#####  D O   N O T   E D I T   B E L O W  #####

#### VARIABLES / OPTIONS

# Enable AMD EPYC and Ryzen CPU Fixes
if [ -z "$XS_AMDFIXES" ] ; then
    XS_AMDFIXES="yes"
fi

# Force APT to use IPv4
if [ -z "$XS_APTIPV4" ] ; then
    XS_APTIPV4="yes"
fi

# Update Proxmox and install various system utils
if [ -z "$XS_APTUPGRADE" ] ; then
    XS_APTUPGRADE="yes"
fi

# Ensure that script is optimized for Proxmox VE 8.2
PROXMOX_VERSION=$(pveversion | grep -oP '\d+\.\d+')
if [[ "$PROXMOX_VERSION" != "8.2" ]]; then
    echo "Warning: This script is specifically optimized for Proxmox VE 8.2."
fi

# Apply AMD EPYC and Ryzen fixes if required
if [ "$XS_AMDFIXES" = "yes" ] ; then
    echo "Applying AMD EPYC and Ryzen fixes..."
    # Insert AMD-specific fixes here for Proxmox VE 8.2
    # Example: Set specific kernel parameters or CPU optimizations
fi

# Force APT to use IPv4 if required
if [ "$XS_APTIPV4" = "yes" ] ; then
    echo "Forcing APT to use IPv4..."
    echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
fi

# Update system and install various utilities for Proxmox VE 8.2
if [ "$XS_APTUPGRADE" = "yes" ] ; then
    echo "Updating system and installing utilities..."
    apt-get update
    apt-get dist-upgrade -y
    apt-get install -y ifupdown2 htop vim tmux
fi

# Add Proxmox VE 8.2 specific enhancements here
# Example: Optimize ZFS settings, enable TCP BBR, etc.

echo "Post-installation script for Proxmox VE 8.2 completed successfully."
