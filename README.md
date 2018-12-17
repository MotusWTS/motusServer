# motusServer

R package to operate a server to process data for http://motus.org
This package processes raw data from receivers and stores results in
a master database.

**Motus users** should not use this package. User data can be accessed either through the motusClient (https://github.com/MotusWTS/motusClient) using the Motus rPackage (documented here: https://motus.org/MotusRBook/) or downloaded directly from the motus platform website: https://motus.org/data/downloads

This server obtains its data from the server above, so there may be a small
time lag before the same data are available.
