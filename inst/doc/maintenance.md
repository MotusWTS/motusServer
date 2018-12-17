# Software Maintenance for the Motus Data-processing Server #

The motus data processing server (hereinafter *Server*) is written
mostly in R to reduce the maintenance burden and increase user
transparency of the entire motus system; i.e. the client package and
server package are in same language.  It uses a fairly small subset of
the R language, and only the recommended packages.  There is no reason
for the client and server target versions of R to be the same; on the
server, stability is critical, while on the client side, tracking new
upstream features might be given more weight.

The Server runs on debian linux 8.8

## Updating the version of R used on the Server ##

- don't update R.  This is almost always the right choice.

- switching to a new X or Y from version X.Y.Z has a significant (Y) or
  highly significant (X) probability of breaking the Server

- R does not (as of 2018-09) have "long-term-support" versions, a
  stable API, or apparently any governance procedures aimed at
  reducing the work of tracking upstream changes.  There is nothing
  inherently wrong with using an older version under-the-hood in a
  production system (beyond what is wrong with using R at all for
  such purposes...)

- the version of R used on the server is kept in a git repo at
  /home/sg/src/R-motus and upstream at https://github.com/jbrzusto/R-motus

- if a hard-to-work-around bug in R is responsible for a problem with
  the Server, it is best to just patch R-motus with the minimal changeset
  that fixes the problem.

- you will typically need to re-install packages, even if you've only
  rebuilt the R executable.  This can take 30 minutes or more,
  requires that the Server not be running, and requies that upstream
  CRAN repositories still have the appropriate versions of packages
  needed by the version of R used on the Server.

- however, as suggested here: http://zvfak.blogspot.com/2012/06/updating-r-but-keeping-your-installed.html
  we install non-bundled R packages to a separate directory,
  `/home/sg/installed-R-packages` so that if only a minor update/upgrade
  is made to R, the packages will be preserved and need not be reinstalled.
  This requires the file `/home/sg/.Renviron` with this line:
```
R_LIBS=/home/sg/installed-R-packages
```

### HOWTO ###
Assuming you really need to update R:

- make changes to the tree in /home/sg/src/R-motus

- consult README.md in that tree to see the history of changes
  made for the Server's version of R

- ensure a successful build with `make`:

```sh
cd /home/sg/src/R-motus
make
```

- do some testing of the newly-built version before installing it system-wide:
```sh
cd /home/sg/src/R-motus
bin/R   ## will run the newly-built version
bin/R -d gdb ## will run the newly-built version with gdb for debugging
```

- install the new version
```sh
cd /home/sg/src/R-motus
sudo make install
```
- re-install required upstream packages; currently, this means:
```R
install.packages(c('roxygen2', 'digest', 'dbplyr', 'dplyr', 'httr', 'jsonlite', 'lubridate', 'openssl', 'proto', 'RMySQL', 'RSQLite', 'sendmailR', 'stringi', 'XML'))
```

- re-install the `motusServer` package:
```sh
cd /home/sg/src/motusServer
rpack -g .
```

- restart all servers
```sh
## kill running servers gracefully, so that jobs
## will be resumed on restart
killAllMotusServers.sh -g
sleep 320 ## wait a bit over 5 minutes for graceful termination
runAllMotusServers.sh
```
- document your changes in /home/sg/src/R-motus/README.md

- if everything appears to be running correctly and your problem has been
fixed, commit the changes to the R-motus repo and send a pull-request
to the R-motus github repo maintainer

- if you see repeated messages such as `running server for queue 1`
on your console, that means the servers are exiting with an error and
then being automatically restarted.  You can diagnose this with the
error dumps in `/sgm/logs/process1.txt`, for example.
