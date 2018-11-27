#!/bin/sh -e
#
# This script is run from /etc/rc.local at the end of each multiuser runlevel.
#
# - create a ramfs which will be used to hold the decrypted Lotek
#   codeset database.  Only the sg user has permission to access this
#   file.
#
# - email admin user(s) about need to enter decryption passphrase
#   and restart servers dependent on the Lotek DB
#
# - restart any servers not dependent on the Lotek DB

mount none /home/sg/ramfs -t ramfs
chown sg:sg /home/sg/ramfs
chmod og-rwx /home/sg/ramfs

(cat <<EOF

The server at sgdata.motus.org has rebooted.  You need to do two things:

1. to allow use of the Lotek codeset database for processing telemetry
data, you need to enter the decryption passphrase.  To do this, login
to the server as user sg (or use `sudo su sg` to become `sg`) and type:

  /sgm/bin/decryptLotekDB.R

This will prompt for the passphrase and then decrypt the database into
locked memory, accessible only by the 'sg' user.

2. after step 1 succeeds, restart any remaining servers which depend
on the Lotek DB by doing this from the shell (again as user `sg`):

  /sgm/bin/runAllMotusServers.sh

-----------------------------------------------------------------------
This email was sent by the script
   /home/sg/installed-R-packages/motusServer/scripts/boot_time_tasks.sh
which was invoked from
  /etc/rc.local

EOF
) | mail -s "motus processing server rebooted; needs you to decrypt Lotek db etc." sg

# run servers *not* dependent on the decrypted Lotek DB:
/sgm/bin/runMotusStatusServer2.sh

exit 0
