#!/bin/bash

# This script downloads and updates the firmware of Western Digital SSDs on Ubuntu / Linux Mint.
# It is only capable of updating, if, and only if the current firmware version is
# directly supported. If not, you have to upgrade to one of these versions first.

# The script assumes the SSD is at /dev/nvme0. Adjust accordingly if your SSD is located elsewhere.
# Firmware updates can be risky.
# Always back up your data and understand the risks before proceeding.
# Use at your own risk

# Copyright (C) 2023 by Jules Kreuer - @not_a_feature
# With adaptations from @Klaas-


# This piece of software is published unter the GNU General Public License v3.0
# TLDR:
#
# | Permissions      | Conditions                   | Limitations |
# | ---------------- | ---------------------------- | ----------- |
# | ✓ Commercial use | Disclose source              | ✕ Liability |
# | ✓ Distribution   | License and copyright notice | ✕ Warranty  |
# | ✓ Modification   | Same license                 |             |
# | ✓ Patent use     | State changes                |             |
# | ✓ Private use    |                              |             |

# Location of the nvme drive.
# Reads the first argument, if it's empty, defaults to /dev/nvme0
nvme_location="${1:-/dev/nvme0}"
version="${2:-}"
base_url="https://sddashboarddownloads.sandisk.com"

# Step 0: Check the requirements
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Re-run the script as 'sudo $0'."
  exit 1
fi

if ! required_nvme="$(type -p "nvme")" || [[ -z $required_nvme ]]; then
  echo "The required package 'nvme-cli' is not installed."
  echo "Please install it using 'sudo apt install nvme-cli'."
  exit 1
fi

if ! required_curl="$(type -p "curl")" || [[ -z $required_curl ]]; then
  echo "The required package 'curl' is not installed."
  echo "Please install it using 'sudo apt install curl'."
  exit 1
fi

if ! required_awk="$(type -p "awk")" || [[ -z $required_awk ]]; then
  echo "The required package 'mawk' is not installed."
  echo "Please install it using 'sudo apt install mawk'."
  exit 1
fi

# Step 1: Get model number and firmware version
model=$(nvme id-ctrl "$nvme_location" | grep -E "mn\s*:" | cut -d':' -f2 | xargs)
firmware_rev=$(nvme id-ctrl "$nvme_location" | grep -E "fr\s*:" | cut -d':' -f2 | xargs)

if [ -z "$model" ] || [ -z "$firmware_rev" ]; then
    echo "Could not read the model and firmware version of $nvme_location."
    exit 1
fi

echo "Device: $nvme_location"
echo "Model: $model"
echo "Firmware Revision: $firmware_rev"
echo
# Replace whitespace in model with underscore
model_under=${model// /_}


# Step 2: Fetch the device list and find the firmware URL
device_list_url="$base_url/wdDashboard/config/devices/lista_devices.xml"
if ! device_list=$(curl -fsS "$device_list_url"); then
    echo "Could not download the device list from $device_list_url."
    exit 1
fi
device_properties_relative_url=$(echo "$device_list" | grep -F "/$model_under/" | grep -oP "(?<=<url>).*?(?=</url>)")

NL=$'\n'  # newline character

if [ -z "$device_properties_relative_url" ]; then
    echo "No matching firmware URL found for model $model."
    exit 1
elif [[ "$device_properties_relative_url" == *"$NL"* ]]; then
    # check if latest version of the multiple firmware versions is already installed
    latest=$(echo "$device_properties_relative_url" | tail -n1 | awk -F'/' '{print $4}')
    if [[ "$firmware_rev" == "$latest" ]]; then
        echo "Already on latest firmware."
	exit 0
    fi
    if [ -z "$version" ]; then
    echo "Multiple firmware versions available from WD. Please select which firmware you want to upgrade to."
    echo "Possible values:"
    echo "$device_properties_relative_url" | awk -F'/' '{print $4}'
    echo "Usage $0 $nvme_location version-string"
    exit 1
    else
        echo "Using version $version"
    fi
    device_properties_relative_url=$(echo "$device_properties_relative_url" | grep -F "/$version/")
    if [ -z "$device_properties_relative_url" ]; then
        echo "Version $version is not available for model $model."
        exit 1
    fi
fi

# Do another check if there is only one firmware version to see if we have latest already installed
latest=$(echo "$device_properties_relative_url" | awk -F'/' '{print $4}')
if [[ "$firmware_rev" == "$latest" ]]; then
    echo "already on latest"
    exit 0
fi

full_device_properties_url="$base_url/$device_properties_relative_url"

# Step 3: Download the device properties XML and parse it
if ! device_properties_xml=$(curl -fsS "$full_device_properties_url"); then
    echo "Could not download $full_device_properties_url."
    exit 1
fi
fwfile=$(echo "$device_properties_xml" | grep -oP "(?<=<fwfile>).*?(?=</fwfile>)")
fwmode=$(echo "$device_properties_xml" | grep -oP "(?<=<fwmode>).*?(?=</fwmode>)")
dependencies=$(echo "$device_properties_xml" | grep -oP "(?<=<dependency model=\"$model\">).*?(?=</dependency>)")

echo "Firmware File: $fwfile"
echo "Dependencies:"
echo "$dependencies"
echo

# Check if current firmware is in dependencies
if ! grep -qxF "$firmware_rev" <<< "$dependencies"; then
    echo "Current firmware version is not in the dependencies. Please upgrade to one of these versions first: $dependencies"
    exit 1
fi

if [[ "$fwmode" != "mode3" ]]; then
    echo "Firmware mode '$fwmode' is not supported. This script only supports mode3."
    exit 1
fi

# Step 4: Download the firmware file
firmware_url=${full_device_properties_url/device_properties.xml/$fwfile}
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
fw_path="$tmp_dir/$fwfile"
echo "Downloading firmware from $firmware_url..."
if ! curl -f -o "$fw_path" "$firmware_url"; then
    echo "Could not download the firmware."
    exit 1
fi

echo
read -r -p "Flash firmware $latest to $model at $nvme_location? [y/N] " answer
if [[ "$answer" != [yY] ]]; then
    echo "Aborted. The firmware was not changed."
    exit 1
fi

# Step 5: Update the firmware
if ! nvme fw-download -f "$fw_path" "$nvme_location"; then
    echo "Firmware download to the drive failed."
    exit 1
fi
echo "Firmware download complete. Switching to new firmware..."
if ! nvme fw-commit -s 2 -a 3 "$nvme_location"; then
    echo "Firmware commit failed."
    exit 1
fi

echo "Firmware update process completed. Please reboot."
