#' code to run after installing a new version of this package.
#'
#' After re-installing the motusServer package, this function is executed
#' to fix ownership, permissions, and links outside the R package tree.
#'
#' If you install the motusServer R package using this command line:
#'
#'    sudo su -c 'cd /home/sg/src/motusServer; /usr/local/bin/rpack -g .' sg
#'
#' then this function will be run by that script.  Otherwise, you can
#' do so manually from the command line like so:
#'
#'    Rscript -e 'motusServer:::postInstall()'
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

postInstall = function() {
    S = function(...) system(sprintf(...))

    ## crontabs: jobs run periodically

    crontabs = dir("/sgm_local/bin", pattern=".*_crontab", full.names=TRUE)

    ## change ownership and permissions because cron requires root
    ## ownership and that the files not be writable by group or others
    ## and then make sure there are links to the crontabs in
    ## /etc/cron.d

    for (t in crontabs) {
        S("sudo chown root:root %s", t)
        S("sudo chmod og-w %s", t)
        S("sudo ln -f -s %s /etc/cron.d", t)
    }
}
