#!/bin/bash

# Things to do after installing the motusServer package.
# must be run as a user who has sudo privileges

## make sure scripts are in the right places before trying to
## modify their properties

Rscript -e 'library(motusServer);ensureServerDirs()'

## make sure cron jobs (re-occurring tasks) are set up correctly

echo setting up crontab for daily sqlite backups

sudo chown root:root /sgm_local/bin/sqlite_daily_backup_crontab
sudo chmod og-w /sgm_local/bin/sqlite_daily_backup_crontab
sudo ln -s /sgm_local/bin/sqlite_daily_backup_crontab /etc/cron.d

sudo chown root:root /sgm_local/bin/refreshMotusMetaDB_crontab
sudo chmod og-w /sgm_local/bin/refreshMotusMetaDB_crontab
sudo ln -s /sgm_local/bin/refreshMotusMetaDB_crontab /etc/cron.d
