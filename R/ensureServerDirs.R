#' Ensure existence of a hierarchy of folders for running a motus
#' data processing server.
#'
#' This will create, if necessary, a set of folders under the root folders
#' \code{/sgm} (for NAS-stored items) and \code{/sgm_hd} (for critical
#' databases stored on the local HD).
#'
#' Folder hierarchy includes these:  (although check motusConstants.R for
#' a complete list)
#'
#' \itemize{
#' \item /sgm/bin - scripts to perform tasks; these will be symlinks to
#'     files in this package's scripts folder
#'     e.g.:  processMessage.py -> /usr/local/lib/R/site-library/motus/scripts/processMessage.py
#'
#' \item /sgm_hd/cache - cached copy of motus metadata
#'     e.g.:  motus_meta_db.sqlite
#'
#' \item /sgm/errors - stack dumps of server errors
#'     e.g.: 2016-09-27T02-24-21.885735_dump.rds
#'
#' \item /sgm/file_repo - repository of raw data files, by receiver
#'
#' \item /sgm/incoming - where new files or directories are linked from or copied to so that
#'    they get processed; the server() function from the motus R package watches
#'    this folder for new entries, then processes them
#'
#' \item /sgm/logs - logfile for each receiver
#'     e.g.:  SG-4001BBBK2230.log.txt
#'
#' \item /sgm/plots - summary plots by receiver and tag
#'     e.g.:  2016_Motus_Walsingham_hourly_old_new.png
#'
#' \item /sgm/pub - public files that can be served to anyone (
#'     e.g.:  the tag deployment timeline
#'
#' \item /sgm/recv - one .motus sqlite database per receiver, by serial number
#'     e.g.:  SG-4001BBBK2230.motus
#'
#' \item /sgm/recvlog - log files retrieved from receivers; this folder will have a subfolder
#'     for each receiver, by serial number, and those folders will have subfolders for each
#'     date at which log files were retrieved
#'     e.g. /sgm/recvlog/SG-4001BBBK2230/2016-07-30/...
#'
#' \item /sgm/tags - one .motus sqlite database per tag project, by motus project code
#'     e.g.:  project_47_tags.motus
#'
#' \item /sgm/tmp - location for temporary processing directories which we don't
#'    want erased on system reboot
#' }
#'
#' @return returns TRUE if any directories had to be created, FALSE otherwise.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}
#'

ensureServerDirs = function() {
    dirs = grep("/$", unlist(MOTUS_PATH), perl=TRUE, value=TRUE)
    rv = any(sapply(
        dirs,
        dir.create,
        recursive = TRUE,     ## create parent dir if necessary
        mode = "0774",        ## full permissions for owner and group, read-only for others
        showWarnings = FALSE  ## ignore warnings of existing dirs
    ))

    ## fix ownership / permission where they were specified

    for (i in seq(along=MOTUS_PATH)) {
        a = attributes(MOTUS_PATH[[i]])
        if (! is.null(a$perm))
            safeSys("chmod", a$perm, MOTUS_PATH[[i]])
        if (! is.null(a$owner))
            safeSys("sudo", "chown", a$owner, MOTUS_PATH[[i]])
    }

    ## create symlinks to package scripts and shared libs from /sgm/bin

    instDir = system.file(c("scripts", "libs"), package="motusServer")
    targets = dir(instDir, full.names=TRUE)
    suppressWarnings(file.symlink(targets, file.path(MOTUS_PATH$BIN, basename(targets))))

    ## create symlinks to scripts for the static webserver; these are e.g. php pages
    ## served by apache and control access to downloads of receiver summary plots etc.

    instDir = system.file("scripts/www", package="motusServer")
    targets = dir(instDir, full.names=TRUE)
    suppressWarnings(file.symlink(targets, file.path(MOTUS_PATH$WWW, basename(targets))))

    return(rv)
}
