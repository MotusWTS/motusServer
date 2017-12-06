#' register a receiver with motus (admin only)
#'
#' @param serno: character vector, such as "SG-1234BBBK5678"
#'
#' @param secretKey: if NULL, generate a pair of public/private ssh keys
#' for the receiver, and use the SHA1-sum of the private key file as the
#' secretKey.  Otherwise, this is an upper case hex string giving the
#' secretKey for the receiver.
#'
#' @return the query result, which will be a list.  If registration is successful,
#' the list will have an integer item named `deviceID`, which is the motus
#' ID for the receiver.
#'
#' @export
#'
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

motusRegisterReceiver = function(serno, secretKey = NULL) {

    if (is.null(secretKey)) {
        newserno = sub("^SG-", "sg_", serno, perl=TRUE)
        ## see whether the receiver already has a private key
        privKeyFile = file.path(MOTUS_PATH$CRYPTO, paste0("id_dsa_", newserno))
        if (! file.exists(privKeyFile)) {
            ## generate a public/private key pair for this receiver
            ## NOTE: if the receiver ever connects via ssh to our server,
            ## it will still have a new keypair generated.

            privKeyFile = file.path(MOTUS_PATH$CRYPTO, paste0("id_dsa_", newserno))
            file.remove(privKeyFile, paste0(privKeyFile, ".pub"))
            safeSys("ssh-keygen", "-q", "-t", "dsa", "-f", privKeyFile, "-N", "")
        }
        privKey = readChar(privKeyFile, 1e5, useBytes=TRUE)
        ## now calculate the SHA1 sum of the private key file, which is what
        ## we use as the receiver's secret key for the motus API

        secretKey = digest(privKey, "sha1", serialize=FALSE)
    }

    masterKey = "~/.secrets/motus_secret_key.txt"

    motusQuery(MOTUS_API_REGISTER_RECEIVER, requestType="get",
               params = list(
                   secretKey = toupper(secretKey),
                   receiverType = getRecvType(serno)
               ),
               serno = serno,
               masterKey = masterKey)
}
