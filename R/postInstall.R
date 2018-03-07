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

    ensureServerDB(installing=TRUE)
    openMotusDB()
    ensureMotusTransferTables()

    ## create links in the web server root direcotry

    ## download directory
    S("sudo ln -s /sgm/www /var/www/html/download")
    S("sudo ln -s /sgm/www/index.html/index.html /var/www/html/index.html")
    S("sudo ln -s /sgm/www/index.php/index.php /var/www/html/index.php")

    ## ugly php login page
    S("sudo ln -s /sgm/www/login.php/login.php /var/www/html/login.php")

    ## public pages not requiring login
    S("sudo ln -s /sgm/pub /var/www/html/public")

    ## additional message for status page
    S("sudo ln -s /sgm_local/bin/www/status_message.html /var/www/html/status_message.html")

    ## upload pages (yes, directly from the source folder.  Not smart!)
    S("sudo ln -s /home/sg/src/ProjectSend /var/www/html/upload")

    ## robots.txt - keep webcrawlers off this server; at most, the /sgm/pub folder would
    ## be worth indexing, but there should be other links to all that content/
    S("sudo ln -s /sgm_local/bin/www/robots.txt /var/www/html/robots.txt")
}
