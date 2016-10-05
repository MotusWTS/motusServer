#' register a receiver with motus (admin only)
#'
#' @param serno: character vector, such as "SG-1234BBBK5678"
#'
#' @param macAddr: MAC address of receiver's 1st ethernet port, as
#' 12 upper-case hex digits without punctuation or spaces.  Defaults
#' to NULL, meaning "not known".
#'
#' @param secretKey: if NULL, generate a pair of public/private ssh keys
#' for the receiver, and use the SHA1-sum of the private key file as the
#' secretKey.  Otherwise, this is an upper case hex string giving the
#' secretKey for the receiver.
#'
#' @return the query result, which won't usually be useful
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusRegisterReceiver = function(serno, macAddr = NULL, secretKey = NULL) {

    if (is.null(secretKey)) {
        newserno = sub("^SG-", "sg_", serno, perl=TRUE)
        ## receiver is a sensorgnome
        ## see whether the receiver already has a private key
        privKeyFile = paste0("/home/sg_remote/.ssh/id_dsa_", newserno)
        privKey = readChar(pipe(paste("sudo cat", privKeyFile), "rb"), 1e5, useBytes=TRUE)
        if (! isTRUE(length(privKey) == 1)) {
            ## generate a public/private key pair for this receiver
            ## NOTE: if the receiver ever connects via ssh to our server,
            ## it will still have a new keypair generated.

            privKeyFile = paste0("/home/sg_remote/.ssh/generated_by_server/id_dsa_", newserno)
            safeSys(printf("sudo rm -f %s %s.pub", privKeyFile, privKeyFile))
            safeSys(sprintf("sudo su -c 'ssh-keygen -q -t dsa -f %s -N \"\"' sg_remote", privKeyFile))
            privKey = readChar(pipe(paste("sudo cat", privKeyFile), "rb"), 1e5, useBytes=TRUE)
        }
        ## now calculate the SHA1 sum of the private key file, which is what
        ## we use as the receiver's secret key for the motus API
        ## the 'sudo cat' is to switch to root user to read the secret private key file
        ## which belongs to user sg_remote

        secretKey = digest(readChar(pipe(paste("sudo cat", privKeyFile), "rb"), 1e5, useBytes=TRUE), "sha1", serialize=FALSE)
    }

    masterKey = "~/.secrets/motus_secret_key.txt"

    motusQuery(MOTUS_API_REGISTER_RECEIVER, requestType="get",
               params=list(
                   secretKey = toupper(secretKey),
                   macAddr = macAddr
               ),
               masterKey = masterKey, serno=serno)
}
