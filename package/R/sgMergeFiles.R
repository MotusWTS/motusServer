#' Merge a batch of raw SG files with an existing database.
#'
#' @param src dplyr src_sqlite to receiver database
#' 
#' @param files either a character vector of full paths to files, or the full
#' path to a directory, which will be searched recursively for raw files.
#'
#' @return a data_frame reporting the fate of each file, with these columns:
#' \enumerate{
#' \item fullname - full path to filename
#' \item new      - TRUE iff file has not yet in database
#' \item done     - TRUE iff file was already \em{complete} in database
#' \item use      - TRUE iff file copied to database, replacing any existing content
#' \item corrupt  - TRUE iff file was compressed but corrupt
#' \item small    - TRUE iff file was smaller than existing copy in database, so not used
#' \item partial  - TRUE iff file was compressed but not complete; not used in this case.
#' \item badrecv  - TRUE iff file was excluded because it was from a different receiver
#' }
#'
#' @export
#' 
#' @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

sgMergeFiles = function(src, files) {
    if (! isTRUE(is.character(files) && all(file.exists(files))))
        stop("invalid or non-existent input files specified")
    if (file.info(files[1])$isdir)
        files = dir(files, recursive=TRUE, full.names=TRUE)
    else
        files = sort(files)
    
    sgEnsureDBTables(src)
    
    ## sqlite connection
    
    con = src$con

    ## clean up the basename, in case there are wonky characters; we
    ## don't do this to "fullname", to maintain our ability to refer
    ## to the files from the filesystem.
    newf = data_frame(
        ID       = 1:length(files),
        fullname = files,
        basename = files %>% basename %>% iconv(to="UTF-8", sub="byte")
    )

    ## split off compression extensions of filenames, if any

    parts = stri_split_regex(newf$basename, "\\.(?=(bz2|gz)*$)", simplify=TRUE)

    newf$name = parts[,1]
    if (ncol(parts) > 1) {
        newf$ext = parts[,2]
    } else {
        newf$ext = ""
    }
    ## existing files in database

    oldf = tbl(src, "files")

    ## On the SG, data are written simultaneously to .txt and .txt.gz files; when
    ## a size or time threshold is reached, the .txt.gz file is closed, and the
    ## uncompressed .txt version is deleted.  Until then, the .txt file will have
    ## more complete data.

    ## Moreover, separate data batches might both have partial copies of compressed
    ## and uncompressed versions of a file.

    ## Here's what we want to do:

    ## - once we have a complete, valid compressed file, preserve only that
    ##   one in the database.  So if the incoming data has a complete, valid compressed
    ##   file, preserve that and delete any existing .txt file.
    ##
    ## - otherwise, preserve only the .txt file in the database;
    ##
    ## - only update the .txt file if it is longer than the copy in the database, so that
    ##   we don't clobber existing data from a corrupt copy

    ## Here's what to do for each file (F) in the new set:
    ##
    ## - if F is in oldf and isDone is TRUE, we do nothing, as complete file is already present
    ## - otherwise, if an uncompressed F is in newf, then copy it to oldf if it is larger than
    ##   than any existing copy
    ## - otherwise, copy the compressed F (if valid) from newf to oldf.

    ## parse filenames into components
    pfc = parseFilenames(newf$name)

    ## modify component names to avoid collisions with names in database 'files' table
    names(pfc) = paste0("F", names(pfc))

    newf = newf %>%
        ## bind parsed components
        bind_cols(pfc) %>%

        ## join against existing files
        left_join(oldf, by="name", copy=TRUE) %>%
        
        ## Mark files for which an existing complete copy is in the database
        ## (note that isDone == NA means the file is not there at all)
        mutate(
            done = is.finite(isDone) & isDone, 
            
            ## Mark compressed version of new files which are present as both
            ## compressed and uncompressed, as the compressed one is incomplete.
            ## Files are sorted by name, so the compressed copy will be marked
            ## as TRUE by duplicated().
            
            partial = duplicated(name),
            
            ## Mark uncompressed files which are not longer than the existing version
            
            nsize = file.info(fullname)[["size"]],
            small = ! is.na(size) & nsize <= size & ! done & ! partial,

            ## Mark files not seen before
            new = is.na(fileID),

            ## Mark files we want to use
            use = ! (done | partial | small),

            ## Assume compressed files are not corrupt
            corrupt = FALSE
            
        )
    
    ## get receiver information; if NULL, grab it from the first file

    ## FIXME? is there a cleaner way to do '%>% collect %>% as.XXX' to get a scalar entry from a tbl?
    
    meta = tbl(src, "meta") %>% filter(key == "recv") %>% select(val)
    updateMeta = FALSE
    if (nrow(meta) > 0) {
        meta = meta %>% collect %>% as.character %>% fromJSON
    } else {
        meta = list(serno = newf$Fserno[1])
        updateMeta = TRUE
    }
    ## because macAddr has not been supplied in the past, we try grab it
    ## if *any* file provides it, so long as it's for the correct recv
    
    if (is.null(meta$macAddr)) {
        first = which(! is.na(newf$FmacAddr))
        if (length(first) > 0 && newf$Fserno[first] == meta$serno) {
            meta$macAddr = newf$FmacAddr[first]
            updateMeta = TRUE
        }
    }

    if (updateMeta) {
        dbGetPreparedQuery(src$con, "insert or replace into meta (key, val) values (:key, :val)",
                           data_frame(key = "recv", val = toJSON(meta, auto_unbox=TRUE)) %>% as.data.frame)
    }

    ## Mark files from different receiver
    newf = newf %>%
        mutate (
            badrecv = (Fserno != meta$serno) | if(is.null(meta$macAddr)) FALSE else meta$macAddr != FmacAddr,
            use     = use & ! badrecv
        )

    now = as.numeric(Sys.time())
    
    for (i in 1:nrow(newf)) {
        if (! newf$use[i])
            next
        
        ## grab file contents as bz2-compressed raw vector
        fcon = tryCatch(
            getFileAsBZ2(newf$fullname[i], newf$ext[i], newf$nsize[i]),
            error = function(e) NULL
        )

        if (is.null(fcon)) {
            warning("Skipping unreadable file", newf$fullname[i], "\nPerhaps it is corrupt?")
            newf$corrupt[i] = TRUE
            next
        }

        if (newf$new[i]) {
            ## not yet in database
            dbGetPreparedQuery(
                con,
                "insert into files (name, size, bootnum, ts, tscode, tsDB, isDone, contents) values (:name, :size, :bootnum, :ts, :tscode, :tsDB, :isDone, :contents)",
                
                data_frame(
                    name     = newf$name[i],
                    size     = attr(fcon, "len"),
                    bootnum  = newf$Fbootnum[i],
                    ts       = newf$Fts[i],
                    tscode   = newf$FtsCode[i],
                    tsDB     = now,
                    isDone   = newf$ext[i] != "",
                    contents = list(fcon)
                ) %>% as.data.frame
            )
        } else {
            dbGetPreparedQuery(
                con,
                "update files set size=:size, contents=:contents where fileID=:fileID ",
                data_frame(
                    size     = attr(fcon, "len"),
                    contents = fcon
                ) %>% as.data.frame ## because dbGetPreparedQuery doesn't test for data.frame inheritance
            )
        }
    }
    return (newf %>%
            transmute(
                use = use & ! corrupt,
                name = fullname,
                new = new,
                done = done,
                use = use,
                corrupt = corrupt,
                small = small,
                partial = partial,
                badrecv = badrecv
            ))
}
