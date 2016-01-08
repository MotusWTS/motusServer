#' Regular expression for parsing data filenames from a sensorgnome receiver.
#'@export

sgFilenameRegex = "^(?<prefix>[^-]+)-(?<serno>[0-9]+BB(BK)?[0-9]+)-((?<macAddr>[0-9a-f]{12})-)?(?<bootnum>[0-9]+)-(?<ts>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}(.[0-9]+)?)(?<tsCode>[P-Z])-(?<port>[a-z]+)(?<extension>\\.[a-z]+)(?<comp>\\.(gz|lz))?$"

