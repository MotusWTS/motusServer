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

options(warn = -1)
sources = c("/home/sg/lotekdb/Lotek4.sqlite.gpg", "/home/sg/lotekdb/Lotek3.sqlite.gpg")
targets = c("/home/sg/ramfs/Lotek4.sqlite",       "/home/sg/ramfs/Lotek3.sqlite")

if (! isTRUE(Sys.getenv("USER") == "sg")) {
    cat("This script must be run as user 'sg'; try:\n\n   sudo su -c /sgm/bin/decryptLotekDB.R sg\n\n")
    q("no")
}
if (isTRUE(all(file.size(targets) > 0)) && ! isTRUE(commandArgs(TRUE)[1] == "-f")) {
    cat("The database appears to have already been decrypted.\nIf not, try:\n\n   /sgm/bin/decryptLotekDB.R -f\n\nto force decryption.\n")
    q("no")
}
cat("I'm going to decrypt the Lotek coded ID databases into locked RAM.\nThis will permit full use of the codeset by code run for privileged users.\nIf you interrupt this script, you might need to do\n\n   stty echo\n\nto restore terminal echo.\nThe passphrase is case-sensitive, and includes spaces.\nPlease enter the passphrase: ")

## because Rscript uses stdin to refer to the script file, we can't just read the
## passphrase from there.
## Instead, spawn a new shell to read the passphrase, with echo turned off temporarily
pp = system("stty -echo; read x; stty echo; printf '%s\n' $x", intern=TRUE)
cat("\n")

## decrypt each file
## we do this into a temporary, then move the temporary to the target, to achieve
## atomicity in case more than one admin attempts to do this at the same time
for (i in seq(along=sources)) {
    cat("Decrypting ", sources[i], "...")
    tmptarget = paste0(targets[i], ".tmp")
    cmd = sprintf("gpg -d --passphrase-fd 0 --batch %s > %s 2>/dev/null && mv -f %s %s", sources[i], tmptarget, tmptarget, targets[i])
    p = pipe(cmd, "w")
    cat(pp, file=p)
    close(p)
    cat("\n")
}

if (isTRUE(all(file.size(targets) > 0))) {
    try({
        for (targ in targets) {
            system(sprintf("sqlite3 %s .schema > /dev/null", targets[i]))
        }
        cat("\nDatabases have been decrypted successfully.\n\nHit enter to start motus data processing servers:\n")
        system("read x; /sgm/bin/runAllMotusServers.sh")
        q("no")
    }, silent=TRUE)
}
cat("\n   Warning: decryption failed. Wrong passphrase?\n\n")
q("no")
