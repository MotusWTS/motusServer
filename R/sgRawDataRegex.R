#' Regular expression for parsing line from raw data file.
#'@export

sgRawDataRegex = "^(?<ltype>([px][0-9]{1,2}|S|G|C)),(?<serno>[0-9]+BB(BK)?[0-9]+)-((?<macAddr>[0-9a-f]{12})-)?(?<bootnum>[0-9]+)-(?<ts>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}(.[0-9]+)?)(?<tsCode>[P-Z])-(?<port>[a-z]+)(?<extension>\\.[a-z]+)(?<comp>\\.(gz|lz))?$"

