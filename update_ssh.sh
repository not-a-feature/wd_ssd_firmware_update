#!/bin/bash

# This script downloads and updates the firmware of Western Digital SSDs on Ubuntu / Linux Mint.
# It is only capable of updating to the latest version, if, and only if the current firmware version
# is directly supported. If not you have to upgrade to one of these versions first.
# The script assumes the SSD is at /dev/nvme0. Adjust accordingly if your SSD is located elsewhere.
# Firmware updates can be risky. Always back up your data and understand the risks before proceeding.
# Use at your own risk

# Copyright (C) 2023 by Jules Kreuer - @not_a_feature
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


# Step 1: Get model number and firmware version
model=$(cat /sys/class/nvme/nvme0/model | xargs)
firmware_rev=$(cat /sys/class/nvme/nvme0/firmware_rev | xargs)

echo "Model: $model"
echo "Firmware Revision: $firmware_rev"
echo
# Replace whitespace in model with underscore
model_under=${model// /_}


# Step 2: Fetch the device list and find the firmware URL
device_list_url="https://wddashboarddownloads.wdc.com/wdDashboard/config/devices/lista_devices.xml"
device_properties_relative_url=$(curl -s $device_list_url | grep $model_under | grep -oP "(?<=<url>).*?(?=</url>)") #

if [ -z "$device_properties_relative_url" ]; then
    echo "No matching firmware URL found for model $model."
    exit 1
fi

full_device_properties_url="https://wddashboarddownloads.wdc.com/$device_properties_relative_url"

# Step 3: Download the device properties XML and parse it
device_properties_xml=$(curl -s $full_device_properties_url)
fwfile=$(echo "$device_properties_xml" | grep -oP "(?<=<fwfile>).*?(?=</fwfile>)")
dependencies=$(echo "$device_properties_xml" | grep -oP "(?<=<dependency model=\"$model\">).*?(?=</dependency>)")

echo "Firmware File: $fwfile"
echo "Dependencies:"
echo $dependencies
echo

# Check if current firmware is in dependencies
if [[ ! "$dependencies" =~ "$firmware_rev" ]]; then
    echo "Current firmware version is not in the dependencies. Please upgrade to one of these versions first: $dependencies"
    exit 1
fi

# Step 4: Download the firmware file
firmware_url=${full_device_properties_url/device_properties.xml/$fwfile}
echo "Downloading firmware from $firmware_url..."
curl -O $firmware_url

echo

# Step 5: Update the firmware
nvme fw-download -f $fwfile /dev/nvme0
echo "Firmware download complete. Switching to new firmware..."
nvme fw-commit -s 2 -a 3 /dev/nvme0

echo "Firmware update process completed. Please reboot."
