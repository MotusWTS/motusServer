# motusServer

R package to operate a server to process data for http://motus.org
This package processes raw data from receivers and stores results in
a master database.

**Motus users**: you don't want this package.  You have two choices:

- get data from the server at sgdata.motus.org using the "motusClient" package available here:  https://github.com/jbrzusto/motusClient
This server processes raw receiver files, so data here are "canonical" and
up-to-date.

- get data from the motus.org server, using the "motus" package (which depends on their fork of "motusClient") here: https://github.com/MotusWTS/motusClient
This server obtains its data from the server above, so there may be a small
time lag before the same data are available here.
