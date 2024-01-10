# WD SSD Firmware Updater for Ubuntu/Linux Mint

This script updates Western Digital (WD) SSD firmware on Ubuntu and Linux Mint systems. 
It was initially developed for frame.work 13 laptops, but can be used for other devices aswell.

See the discussion on: https://community.frame.work/t/western-digital-drive-update-guide-without-windows-wd-dashboard/20616

**Important Notes:**
- This script only updates if the current firmware version is directly supported.
- Firmware updates can be risky. Always back up your data and understand the risks before proceeding.
- Use at your own risk.

## Usage

0. Download update_ssd.sh from this repo.
1. Ensure the SSD is located at `/dev/nvme0` or modify the script accordingly.
3. Run the script: `sudo ./update_ssh.sh`.

## Requirements

- `nvme-cli`: Required for interacting with NVMe devices.
- `mawk`: Required for processing text data.

## Contributors

| Contributor        | GitHub Handle   | Contributions   |
| ------------------ | --------------- | --------------- |
| Jules Kreuer       | @not_a_feature  | Author          |
| Klaas Demter       | @Klaas-         | Adaptations     |
| Edward Felder      |                 | Initial idea    |
| Oleksandr Lutai    |                 | Initial idea    |
