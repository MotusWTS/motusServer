# motusServer

R package to operate a server to process data for http://motus.org

**Motus users**: you don't want this package.  You want
the "motus" package available here:  https://github.com/jbrzusto/motus

This package processes raw data from receivers and stores results in
transfer tables which are polled by the server at Motus. Results use
native motus database keys, which are obtained by querying motus.org
for metadata on tags and receivers.
