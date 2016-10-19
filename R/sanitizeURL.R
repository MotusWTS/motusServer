#' rewrite a URL to remove any authorization credentials.
#'
#' The resulting URL will still look enough like the original to allow
#' a user with access to the original to match it to the sanitized version.
#'
#' @details When users send data files, we'd like to have a public record of
#' downloading and processing, but URLs can contain implicit or explicit
#' credentials which we don't want to make public.
#'
#' This function applies an appropriate method to the given URL to ensure this.
#'
#' @param url character scalar; location of downloadable resource
#'
#' @param method character scalar; method for downloadable resource,
#'     as determined from \code{dataTransferRegex}.  Defaults to "generic",
#'     which does a generic sanitization.
#'
#' @return \code{url} with sufficient portions removed to prevent unauthorized use.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sanitizeURL = function(url, method="generic") {
    parts = strsplit(url, "/")[[1]]
    ## always remove username:password portion preceding hostname
    parts[3] = sub(".*:.*@", "", parts[3], perl=TRUE)
    
    switch(method,
           ## A link from https://wetransfer.com from the sender's confirmation email
           ## e.g. https://we.tl/nV6Uc5KHs5
           wetransferConf = {
               parts[4] <- paste0(substring(parts[4], 1, 3), "...")
           },

           ## A link directly from https://wetransfer.com
           ## e.g. https://www.wetransfer.com/downloads/74f82c0655e1eb53db89fbd31e606bdd201608034623/932867cd82a0664f2687eed55cf7d95220160829034623/a9ef2e
           wetransferDirect = {
               parts[5:6] <- "..."
           },

           ## A link for a shared google drive file or folder
           ## e.g. https://drive.google.com/folderview?id=0B-bl0wW8891FEy2QVpXOUU&usp=sharing
           ## or   https://drive.google.com/open?id=3D0B-bl0wWafEk1F1Y0hMdGZJQkk
           ## or   https://drive.google.com/file/d/0Bx3KaXOwqMcBU1NfMTlOSHFUVm8/view?usp=drive_web
           ## or   https://drive.google.com/drive/folders/0B-bl0wW8KbDxb2FQc3kwLU5YQnc?usp=sharing

           googleDrive = {
               parts <- sub("(?<=[[:alnum:]]{6})[[:alnum:]]{10,}", "...", parts, perl=TRUE)
           },

           ## A link from dropbox
           ## e.g. https://www.dropbox.com/s/biie8sdq0oc5jm6/testfile.txt?dl=0

           dropbox = {
               parts <- sub("(?<=[[:alnum:]]{4})[[:alnum:]]{10,}", "...", parts, perl=TRUE)
           },

           ## for FTP, leave alone, as username:password have already been removed

           FTP = {
               },
           
           ## otherwise, replace each portion of the path after the hostname
           ## with its first three characters and "..."
           
           parts[-(1:3)] <- sub("(?<=.{3}).*", "...", parts[-(1:3)], perl=TRUE)
           )

    paste(parts, collapse="/")
}
