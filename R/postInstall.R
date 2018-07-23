#' code to run after installing a new version of this package.
#'
#' @param root character scalar path to root of installation.
#'     Default: "/" This parameter allows testing the function without
#'     clobbering system files.  e.g. specifying
#'     \code{root="/tmp/PItest"} will create the folder "/tmp/PItest"
#'     and then install the root_overlay files there.
#'
#' @details After (re-)installing the motusServer package, this
#'     function is executed to install files outside the R package
#'     tree, and set ownership and permissions appropriately.  Details
#'     of which files are installed is in the file
#'     inst/root_overlay.md
#'
#' If you install the motusServer R package using this command line:
#'
#'    sudo su -c 'cd /home/sg/src/motusServer; /usr/local/bin/rpack -g .' sg
#'
#' then this function will be run by that script.  Otherwise, you can
#' do so manually from the shell like this:
#'
#'    Rscript -e 'motusServer:::postInstall()'
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

postInstall = function(root = "/") {

    ## parse out file config lines which look like:
    ##  \code{%! shell command line} for a shell command to be run
    ##  \code{% OWNER GROUP MODE PATH} for a file to be copied from the inst/root_overlay folder
    ##  \code{% X -> Y} for a symlink to be created pointing from X to Y

    overlayRX = "(?mx)
# lines giving files start with a percent sign
^%

((
# shell command
!
(?<cmd>.*$)
)

|

(
# symbolic file owner
[[:space:]]+
(?<owner>[^[:space:]]++)

[[:space:]]++

# symbolic file group
(?<group>[^[:space:]]++)

[[:space:]]++

# file permissions
(?<mode>[^[:space:]]++)

[[:space:]]++

# absolute file path, also path relative to root_overlay folder

(?<path>[^[:space:]]++)
)

|

(
# optional symlink src and destination
[[:space:]]+

(?<sym_src>[^[:space:]]++)

(?:[[:space:]]*)

->

(?:[[:space:]]*)

(?<sym_dst>[^[:space:]]*)

)
)
"
    src_root = system.file("root_overlay", package="motusServer")
    ov = splitToDF(overlayRX, readLines(system.file("root_overlay.md", package="motusServer")), guess=FALSE)

    SUDO = function(a, ...) {
        system(sprintf(paste("sudo", a), ...))
    }
    for (i in seq_len(nrow(ov))) {
        if (ov$cmd[i] != "") {
            system(ov$cmd[i])
        } else if (ov$sym_src[i] == "") {
            ## copy normal file
            src = file.path(src_root, ov$path[i])
            SUDO("cp '%s'  '%s';       sudo  chown %s:%s '%s';               sudo chmod %s '%s'",
                                     src, ov$path[i], ov$owner[i], ov$group[i], ov$path[i], ov$mode[i], ov$path[i])
        } else {
            SUDO("ln -s -f '%s' '%s'", ov$sym_dst[i], ov$sym_src[i])
        }
    }
}
