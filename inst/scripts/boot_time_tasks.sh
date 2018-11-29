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

The server at sgdata.motus.org has rebooted.

To allow use of the Lotek codeset database for processing telemetry
data, you need to enter the decryption passphrase.  To do this, login
to the server as user sg (or use `sudo su sg` to become `sg`) and
type:

  /sgm/bin/decryptLotekDB.R

This will prompt for the passphrase and then decrypt the database into
locked memory, accessible only by the 'sg' user.  If the decryption
has already occurred (e.g. another admin has done it), the script
will notice this and exit.  Decryption is performed atomically,
so once the decrypted database is available, it will continue to be
available even if another admin forces a decryption.

If decryption succeeds, the script will prompt you to hit enter to
restart any remaining servers which depend on the Lotek DB.  You
can hit Ctrl-C to prevent this.

In the unlikely event there are corrupt versions of the decrypted
Lotek DBs, you can run the script with the '-f' flag to force
decryption and overwrite of these versions, like so:

  /sgm/bin/decryptLotekDB.R -f

-----------------------------------------------------------------------
This email was sent by the script
   /home/sg/installed-R-packages/motusServer/scripts/boot_time_tasks.sh
which was invoked from
  /etc/rc.local

EOF
) | mail -s "motus processing server rebooted; needs you to decrypt Lotek db" sg

# run servers *not* dependent on the decrypted Lotek DB:
/sgm/bin/runMotusStatusServer2.sh

exit 0
