## read a lotek .DTA file (from filename, or from text lines) and return a list with these items:
##   recv: receiver model + SN
##   tags: a data.frame with these columns:
##
##     ts      - numeric GMT timestamp
##     id      - integer, no 999s
##     ant     - factor - Lotek antenna name
##     sig     - signal strength, in raw Lotek units (0..255)
##     lat     - if available, NA otherwise
##     lon     - if available, NA otherwise
##     dtaline - line in the original .DTA file for this detection
##     antfreq - antenna listening frequency, in MHz
##     gain    - gain setting in place during this detection (0..99)
##     codeset - factor - Lotek codset name
##   pieces: chunks of text of various types
##   piece.lines.before: number of lines before pieces of various types

## We process the file in order, so that changes to antenna frequency
## settings etc. are taken into account.

readDTA = function(filename="", lines=NULL) {

  if (is.null(lines))
    ## read the DTA file in; we don't sweat line endings this way
    lines = readLines(filename)

  date.format = "%m/%d/%y %H:%M:%OS"

  ## frequency and gain tables, needed for figuring out the antenna frequency and
  ## power for each detection
  
  gain.tab = numeric()
  freq.tab = numeric()


  ## receiver model is first word in file
  model = strsplit(lines[1], " ")[[1]][1]

  ## paste text into one big string
  lines = paste(lines, collapse="\n")

  ## start with a NULL tags dataframe
  tags = NULL
    
  ## match against a regular expression to find tables - this splits the file
  ## up into recognizable blocks, in the order in which they appear there
  ## We read and interpret those blocks later.
  
  res = gregexpr(lotekDTAregex, lines, perl=TRUE)[[1]]
  clen = t(attr(res, "capture.length"))
  cstart = t(attr(res, "capture.start"))
  parts = clen != 0
  pieces = substring(lines, cstart[parts], cstart[parts] + clen[parts] - 1)
  names(pieces) = rownames(clen)[1 + ((which(parts)-1) %% nrow(clen))]
  newlines = gregexpr("\n", lines)[[1]]
  piece.lines.before = sapply(cstart[parts], function(x) sum(newlines < x))

  ## each element of the character vector 'pieces' is the body of a
  ## table.
  ## Interpret these now.

  codeset = as.character(NA)
  
  for (ip in seq(along=pieces)) {
    if (nchar(pieces[ip]) == 0)
      next
    
    piece.name = names(pieces)[ip] ## can be repeated

    ## to keep line counts valid, retain blank lines within tables as rows of NA
    
    con = textConnection(pieces[ip])
    tab = read.table(con, as.is=TRUE, blank.lines.skip=FALSE)
    close(con)
    
    switch(piece.name,
           serial_no = {
             serno = tab[1,1]
           },
           
           code_set = {
             codeset = tab[1,1]
           },

           active_scan = {
             ## make a lookup table for frequency by channel
             freq.tab[as.character(tab[,1])] = tab[,2]
           },

           antenna_gain = {
             ## make a lookup table for gain by antenna
             ## We use this to adjust observed power i.e. we reduce
             ## power by a factor of gain.  A brief lab trial
             ## showed an approximate increase of recorded signal
             ## strength of 40 units for each 10 unit increase in gain,
             ## so we reduce signal strength by 4 * gain before converting
             ## to dB way below.
             gain.tab[as.character(tab[,1])] = tab[,2]
           },

           ## default =
           {
             ## this is a table of tag hits, either ID only or ID + GPS
             tab[1] = as.numeric(as.POSIXct(strptime(paste(tab[[1]], tab[[2]]), date.format, tz="GMT")))
             tab = tab[-2]
             if (piece.name == "id_only")
               tab = cbind(tab, 999, 999)  ## lat and lon not available
             
             names(tab) = c("ts", "chan", "id", "ant", "sig", "lat", "lon")
             tab$dtaline = piece.lines.before[ip] + 1:nrow(tab)
             tab$ant = as.character(tab$ant)

             ## fill in the appropriate gain value, or a best guess
             
             ants = unique(tab$ant)
             bad.ants = is.na(gain.tab[ants])
             if (any(bad.ants)) {
               ## the table refers to antenna for which we haven't seen a gain settings
               ## It appears that on the SRX-DL, if there are two antennas,
               ## and one of them is AH0, that antenna appears with a number in tag hit records
               if (sum(bad.ants) == 1 && !is.na(gain.tab["AH0"]) && ! all(tab$ant  == "AH0")) {
                 ## use the gain for AH0, as this is presumably the same antenna
                 gain.tab[ants[bad.ants]] = gain.tab["AH0"]
               } else {
                 ## use the gain from the first antenna with known gain, otherwise, use
                 ## 80 as this was common
                 if (all(is.na(gain.tab))) {
                   gain.to.use = 80
                   gain.source = " but NO GAIN VALUES WERE SPECIFIED FOR ANY ANTENNA!"
                 } else {
                   gain.to.use = gain.tab[which(!is.na(gain.tab))[1]]
                   gain.source = paste(" specified for antenna '", names(gain.tab)[which(!is.na(gain.tab))[1]], "'", sep="")
                 }
                 gain.tab[ants[bad.ants]] = gain.to.use
                 warning("Warning: No gain setting found for antenna number(s): ", paste(ants[bad.ants], collapse=", "),
                         " specified in ", piece.name, " table.\nUsing gain value of ", gain.to.use, gain.source, "\n")
               }
             }
             ## get frequency from latest frequency table
             tab$antfreq = freq.tab[as.character(tab$chan)]

             ## report the gain setting in use
             tab$gain = gain.tab[tab$ant]

             ## fill in the current codeset
             tab$codeset = factor(1, labels=codeset)

             ## remove the channel setting, which is redundant
             tab$chan = NULL

             tags = rbind(tags, tab)
           }
           )
  }
  ## sort in order by time; record with and without GPS fixes are segregated
  ## in the DTA file, even though their timestamps might be interleaved.
  ## (why are GPS fixes intermittent? weird...)
  
  tags = tags[order(tags$ts),]
  return (list(tags=tags, recv = paste(model, serno, sep="-"), pieces=pieces, piece.lines.before=piece.lines.before))
}
