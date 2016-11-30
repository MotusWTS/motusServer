#External Programs#

This is a list of external programs required to run a data processing
server on a debian box using the 'motusServer' R package.

##ripmime##
Full, recursive unpacking of emails; unlike the standard
munpack utility, ripmime deals correctly with attached emails etc., so
that admin users can "bless" emails with their own tokens and resubmit
them for processing in case of errors (e.g. if a user forgot to
include a token, or used an expired one)
https://github.com/inflex/ripMIME

##gdrive##
Download files from drive.google.com
https://github.com/prasmussen/gdrive

##inotifywait##
Watch a directory for changes, such as new files
debian package: inotify-tools

##Dropbox-Uploader##
Grab files from dropbox.com via the command line
https://github.com/andreafabrizi/Dropbox-Uploader

This can't deal with the most obvious way of sharing a file, but
that's because the dropbox API doesn't support it - see:

   https://www.dropboxforum.com/hc/en-us/community/posts/206649516-Import-Email-shared-file-by-api-?page=1#community_comment_212400843

##unrar##
Decompress rar archives
debian package: unrar
