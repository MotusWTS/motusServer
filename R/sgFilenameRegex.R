#' Regular expression for parsing data filenames from a sensorgnome receiver.
#'@export

sgFilenameRegex = "(?i)^(?<prefix>[^-]+)-(?<serno>[0-9A-Z]{4}(?:RP[A-Z0-9]{2}|BBBK|BB[0-9][0-9A-Z])[0-9A-Z]{4}(?:_[0-9])?|CTT-V?[0-9A-F]+|SEI_[A-Z]_[A-Z0-9]{9})-(?<bootnum>[0-9]+)-(?<tsString>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}(.[0-9]+)?)(?<tsCode>[P-Z])-(?<port>[a-z]+)(?<extension>\\.[a-z]+)(?<comp>\\.(gz|lz|bz2))?$"
