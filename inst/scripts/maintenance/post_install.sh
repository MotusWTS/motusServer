#!/bin/bash

# Things to do after installing the motusServer package.
# must be run as a user who has sudo privileges

## make sure scripts are in the right places before trying to
## modify their properties

Rscript -e 'library(motusServer);ensureServerDirs()'

## make sure cron jobs (re-occuring tasks) are set up correctly

echo setting up crontab for daily sqlite backups

sudo chown root:root /sgm_hd/bin/sqlite_daily_backup_crontab
sudo chmod og-w /sgm_hd/bin/sqlite_daily_backup_crontab
sudo ln -s /sgm_hd/bin/sqlite_daily_backup_crontab /etc/cron.d

echo setting up crontab for daily mariadb/mysql backups

sudo chown root:root /sgm_hd/bin/mariadb_daily_backup_crontab
sudo chmod og-w /sgm_hd/bin/mariadb_daily_backup_crontab
sudo ln -s /sgm_hd/bin/mariadb_daily_backup_crontab /etc/cron.d
