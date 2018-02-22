#' A PCRE-style regular expression for matching interesting parts of
#' Lotek .DTA files.  Note that we use the 'possessive' version of
#' non-zero repeats  i.e. '++' instead of '+', as this prevents huge
#' consumption of stack space for possible backtracking, which we never
#' need here.


ltDTAregex =
"(?sx)

# We're looking for model information at top of file:

(?<model>SRX[^ \\n]++)[^\\n]+Information:\\n

# or an 'Environment History' message that seems to indicate
# a receiver restart, giving its date and time:

|
(?:Environment[[:blank:]]++History:\\n
changed:[[:blank:]]++(?<boottime>[0-9]{2}/[0-9]{2}/[0-9]{2}[[:blank:]]++[0-9]{2}:[0-9]{2}:[0-9]{2}))

# or a 'Site Code' message which reports a user-specified
# deployment code.  `readDTA()` uses this to distinguish between receivers
# with the same reported serial number.

|
(?:Site[[:blank:]]++Code:[[:blank:]]*(?<site_code>[0-9]{4})\\n)

# or an active scan table:

|
(?:Active[[:blank:]]++scan_table:\\n
CHANNEL[[:blank:]]++FREQUENCY[[:blank:]]++STATUS[[:blank:]]++TYPE\\n
(?<active_scan>(?:[^\\n]++\\n)++)  ## capture lines until a blank line
\\n)

# or an antenna gain table:

 |
(?:Antenna[[:blank:]]++Gain\\n
(?<antenna_gain>(?:[^\\n]++\\n)++)
\\n)

# Or an ID + GPS positions table:

|
(?:ID[[:blank:]]++\\+[[:blank:]]++GPS[[:blank:]]++Positions:\\n\\n
[[:blank:]]++Date[[:blank:]]++Time[[:blank:]]++Channel[[:blank:]]++Tag[[:blank:]]++ID[[:blank:]]++Antenna[[:blank:]]++Power[[:blank:]]++Latitude[[:blank:]]++Longitude\\n
(?<id_gps>(?:[0-9][^\\n]++\\n{1,2})++)
)

# Or an ID only table:

|
(?:ID[[:blank:]]++Only[[:blank:]]++Records:\\n\\n
[[:blank:]]++Date[[:blank:]]++Time[[:blank:]]++Channel[[:blank:]]++Tag[[:blank:]]++ID[[:blank:]]++Antenna[[:blank:]]++Power\\n
(?<id_only>(?:[0-9][^\\n]++\\n{1,2})++)
)

# Or a codeset identifier:

|
(?:Code[[:blank:]]++Set:[[:blank:]]++
(?<code_set>[a-zA-Z0-9]++)
\\n)

# Or a receiver serial number:

|
(?:Receiver[[:blank:]]++S\\/N:[[:blank:]]++
(?<serial_no>[a-zA-Z0-9]++)
\\n)

# Or a manually triggered coded record section
|
(?:CODED[[:blank:]]++\\(\\+[[:blank:]]++2D[[:blank:]]++GPS\\):\\n\\n[[:blank:]]++Date[[:blank:]]++Time[[:blank:]]++Freq[[:blank:]]++\\[MHz\\][[:blank:]]++Gain[[:blank:]]++Tag[[:blank:]]++ID[[:blank:]]++Antenna[[:blank:]]++Power[[:blank:]]++Data[[:blank:]]++Latitude[[:blank:]]++Longitude\\n(?<id_manual>(?:[0-9][^\\n]++\\n{1,2})++)
)
"
