#!/usr/bin/Rscript --vanilla
##
## decrypt the Lotek codeset database
##
## Prompt the user for a passphrase and use it to decrypt the Lotek
## coded ID databases into locked RAM.  This needs to happen each time
## the server is rebooted.  Only the user 'sg' will have access
## to the database, but it can be delegated to by any process with sudo
## privileges.  Encrypted copies of the Lotek codeset database are
## stored as /home/sg/lotekdb/Lotek[34].sqlite.gpg
##
## Run this script from the shell by doing:
##
##   sudo su sg  # if not already logged in as user sg
##   /sgm/bin/decryptLotekDB.R
##

cat("\n\nI'm going to decrypt the Lotek coded ID databases into locked RAM.\nThis will permit full use of the codeset by code run for privileged users.\nThe passphrase is case-sensitive, and includes spaces.\nPlease enter it now: ")

options(warn = -1)
source = "/home/sg/lotekdb/Lotek4.sqlite.gpg"
target = "/home/sg/ramfs/Lotek4.sqlite"
## because of how Rscript works, we can't just read a line from stdin, so
## instead, spawn a new shell to read in the passphrase, with echo turned off temporarily
pp = system("stty -echo; read x; stty echo; printf '%s\n' $x", intern=TRUE)

cmd = sprintf("sudo su -c 'umask 077; gpg -d --passphrase-fd 0 --batch %s > %s 2>/dev/null' sg\n", source, target)

p = pipe(cmd, "w")

cat(pp, file=p)

close(p)

source = "/home/sg/lotekdb/Lotek3.sqlite.gpg"
target = "/home/sg/ramfs/Lotek3.sqlite"

cmd = sprintf("sudo su -c 'umask 077; gpg -d --passphrase-fd 0 --batch %s > %s 2>/dev/null' sg\n", source, target)

p = pipe(cmd, "w")

cat(pp, file=p)

close(p)

size = as.integer(system(sprintf("sudo su -c 'stat -c %%s %s' sg", target), intern=TRUE, ignore.stderr=TRUE))
if (isTRUE(size > 0)) {
    cat("\n   This seems to have worked!\n\n")
} else {
    cat("\n   Warning: this failed.  You can try again.\n\n")
}
q("yes")
