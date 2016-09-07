#' Ensure existence of a hierarchy of folders for running a motus
#' data processing server.
#'
#' This will create, if necessary, a set of folders under the root folder
#' \code{/sgm}
#'
#' Folder hierarchy:
#'
#' \itemize{
#' \item /sgm/bin - scripts to perform tasks; these will be symlinks to
#'     files in this package's scripts folder
#'     e.g.:  processMessage.py -> /usr/local/lib/R/site-library/motus/scripts/processMessage.py
#'
#' \item /sgm/cache - cached copy of motus metadata
#'     e.g.:  motus_meta_db.sqlite
#'
#' \item /sgm/emails - emails, compressed using bzip2
#'     e.g.:  msg_2016-08-25T14-14-11.810349.txt.bz2
#'
#' \item /sgm/incoming - where new files or directories are linked from or copied to so that
#'    they get processed; the server() function from the motus R package watches
#'    this folder for new entries, then processes them
#'
#' \item /sgm/logs - logfile for each receiver
#'     e.g.:  SG-4001BBBK2230.log.txt
#'
#' \item /sgm/motr - symlink to receivers by motus device ID
#'     e.g.:  181 -> /sgm/recv/SG-4001BBBK2230.motus
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
#' \item /sgm/refs - symlinks by old SG hierarchy to receiver(s) used at a given Year, Project, Site
#'     e.g.:  2014_adamsmith_block_island1 -> /sgm/recv/SG-4001BBBK2230.motus
#'
#' \item /sgm/spam - emails which are not recognized as valid
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
    rv = any(sapply(
        MOTUS_PATH,
        dir.create,
        recursive = TRUE,     ## create parent dir if necessary
        mode = "0774",        ## full permissions for owner and group, read-only for others
        showWarnings = FALSE  ## ignore warnings of existing dirs
    ))

    ## create symlinks to package scripts

    instDir = system.file("scripts", package="motus")
    suppressWarnings(file.symlink(dir(instDir, full.names=TRUE), file.path(MOTUS_PATH$BIN, dir(instDir))))

    return(rv)
}
