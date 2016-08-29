#' A PCRE-style regular expression for matching URLs in an email
#' message sent to share data.

dataTransferRegex = 
"(?sx)

# A link from https://wetransfer.com from the sender's confirmation email
# e.g. https://we.tl/nV6Uc5KHs5

((?<wetransferConf>https://we.tl/[[:alnum:]]++)[[:space:]]*$)

# or
#
# A link directly from https://wetransfer.com
# e.g. https://www.wetransfer.com/downloads/74f82c0655e1eb53db89fbd31e606bdd201608034623/932867cd82a0664f2687eed55cf7d95220160829034623/a9ef2e

|
((?<wetransferDirect>https://(www\\.)?wetransfer.com/downloads/[[:xdigit:]]++/[[:xdigit:]]++/[[:xdigit:]]++))

# or
#
# A link for a shared google drive file or folder
# e.g. https://drive.google.com/folderview?id=0B-bl0wW8891FEy2QVpXOUU&usp=sharing
# or   https://drive.google.com/open?id=3D0B-bl0wWafEk1F1Y0hMdGZJQkk

|
((?<googleDrive>https://drive.google.com/[^[:space:]]*id=[-[:alnum:]]*[^[:space:]]*)[[:space:]])

#or
#
# A link from dropbox
#
# FIXME: unsupported for now

#or
#
# An FTP URL:
|
((?<FTP>ftp://[^[:space:]])[[:space:]])
"

