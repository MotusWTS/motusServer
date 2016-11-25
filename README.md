# motusServer

Operate a server to process data for http://motus.org

**Motus users**: you don't want this package.  You want
the "motus" package available here:  https://github.com/jbrzusto/motus

This package processes raw data from receivers and store results in
transfer tables which are polled by http://motus.org . Results use
native motus database keys, which are obtained by querying motus.org
for metadata on tags and receivers.
