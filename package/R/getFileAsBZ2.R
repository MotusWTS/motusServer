#' read a file and (re-) compress it into a bzip2-format raw vector
#'
#' @param f full path to file.  This can be an uncompressed file, or
#' one compressed with gzip (extension must be ".gz") or bzip2 (extension
#' must be ".bz2").
#'
#' @param ext [optional] file extension.  If not supplied, the
#' extension is the substring of \code{f} beginning with the last period (\code{'.'}))
#'
#' @param size [optional] size of file on disk. If not supplied, it
#' is obtained by a call to file.info
#' 
#' @return a raw vector of bzip2-compressed data, with attribute \code{"len"},
#' giving the length of the uncompressed data.
#'
#' @note If the file \code{f} is empty, this returns a raw vector of length 0.
#' 
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

getFileAsBZ2 = function(f, ext=stri_extract_last_regex(f, "\\.[A-Za-z0-9]*$"), size=file.info(f)$size) {
    if (size == 0)
        return(structure(raw(0), len=0))
    
    val = readBin(f, raw(), size)
    if (ext == "bz2") {
        attr(val, "len") = length(memDecompress(val, "bzip2")) ## just get length of uncompressed
    } else {
        if (ext == "gz") {
            rc = rawConnection(val)
            gc = gzcon(rc)
            ## we don't know the uncompressed size, so assume a compression ratio of 4
            ## and read chunks until we get a partial one.
            val = raw(0)
            i = 1
            cs = 4 * size 
            repeat {
                val = c(val, readBin(gc, raw(), cs))
                if (length(val) < i * cs)
                    break
                i = i + 1
            }
            close(gc)  ## this does a close(rc)
        }
        val = structure(memCompress(val, "bzip2"), len=length(val))
    }
    return(val)
}
