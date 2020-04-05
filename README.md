# terraform-enterprise-backup-service

> DISCLAIMER: This is very much a WIP, there is no SLA provider on the code in this repository. Use at your own risk and never in production.

Repository to create backup and restore services in Terraform Enterprise.

## How to Use

```sh
curl -Lo tfe-backup.zip https://github.com/straubt1/terraform-enterprise-backup-service/archive/master.zip && \
unzip tfe-backup.zip && \
cd terraform-enterprise-backup-service-master

# Backup
./tfdr install-backup "<S3 Bucket Name>" "<Backup Password>"
./tfdr enable-backup

# Restore
./tfdr install-restore "<S3 Bucket Name>" "<Backup Password>"
./tfdr enable-restore
```
## Backup Service

* Creates a backup on a cadence from TFE
* Pushes backup to an S3 bucket

## Restore Services

* Polls an S3 bucket for a newer backup
* If found, copies backup and restores TFE using it

## Testing

TODO: remove

```sh
# backup
sudo ./tfedr install-backup "a" "b"
sudo ./tfedr enable-backup


sudo ./tfedr uninstall-backup

ls /etc/systemd/system/tfe-backup.*
ls /etc/tfe/tfe-backup.*
systemctl is-enabled tfe-backup.service
systemctl is-enabled tfe-backup.timer

ls /etc/systemd/system/tfe-restore.*
ls /etc/tfe/tfe-restore.*
systemctl is-enabled tfe-restore.service
systemctl is-enabled tfe-restore.timer
```