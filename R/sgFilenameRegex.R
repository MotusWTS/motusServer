#' Regular expression for parsing data filenames from a sensorgnome receiver.
#'@export

sgFilenameRegex = "^(?<prefix>[^-]+)-(?<serno>[0-9A-Z]{4}(RPi[23Z]|BBBK|BB)[0-9A-Z]{4,6}(_[0-9])?)-(?<bootnum>[0-9]+)-(?<ts>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}(.[0-9]+)?)(?<tsCode>[P-Z])-(?<port>[a-z]+)(?<extension>\\.[a-z]+)(?<comp>\\.(gz|lz|bz2))?$"
