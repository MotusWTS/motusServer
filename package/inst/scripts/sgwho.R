#!/usr/bin/Rscript
#
# list of connected receivers
#
suppressMessages(library(RSQLite))

ARGS = commandArgs(TRUE)
PORTS = system("netstat -n -l -t 2>/dev/null", intern=TRUE)
PORTS = grep("127\\.0\\.0\\.1", PORTS, value=TRUE)
PORTS = as.numeric(lapply(strsplit(PORTS, " +", perl=TRUE), function(x) strsplit(x[4], ":", fixed=TRUE)[[1]][2]))
PORTS = sort(PORTS[PORTS >= 40000 & PORTS  < 50000])

if (isTRUE(ARGS[1] == "-p")) {
        cat(paste(PORTS, collapse="\n"),"\n")
        q(save="no")
}

RECVS = paste0("SG-", sort(dir("/home/sg_remote/connections")))

YEAR = strftime(Sys.time(), "%Y")
CON = dbConnect(SQLite(), paste0("/SG/", YEAR, "_receiver_serno.sqlite"))
dbGetQuery(CON, "attach database '/home/sg_remote/receivers.sqlite' as d")

QUERY=paste0("select printf('%s %s:%s', t1.Serno, t1.Project, t1.Site) from map as t1 left join map as t2 on t1.Serno=t2.Serno and t1.tsHi < t2.tsHi where t2.tsHi is NULL and t1.Serno in (", paste0("'", RECVS, "'", collapse=","), ")")
RES = unlist(dbGetQuery(CON, QUERY))

cat(paste0("Streaming or Registering:\n", paste0(RES, collapse="\n"), "\n"))

QUERY=paste0("select printf('%s,%5d %s:%s', t1.Serno, t3.tunnelport, t1.Project, t1.Site) from map as t1 left join map as t2 on t1.Serno=t2.Serno and t1.tsHi < t2.tsHi join d.receivers as t3 on 'SG-' || t3.serno = t1.Serno where t2.tsHi is NULL and t3.tunnelport in (", paste0(PORTS, collapse=","), ")")

RES = unlist(dbGetQuery(CON, QUERY))
cat(paste0("\nTunnel Ports:\n", paste0(RES, collapse="\n"), "\n"))

## original shell code was:
###  #!/bin/bash
###  #
###  # list of connected receivers
###  #
###  
###  if [[ "$1" == "-p" ]]; then 
###      sqlite3 -separator ',' ~sg_remote/receivers.sqlite "select tunnelPort from receivers where tunnelPort in (`netstat -n -l -t 2>/dev/null | grep 127.0.0.1 | gawk '{split($4, A, /:/); pn=0+A[2]; if (pn >= 40000 && pn < 50000) {x = x (x ? \",\" : \"\") pn}}END{print x}'`)" | sort
###  else
###      echo "Streaming or Registering:"
###      ls -1 ~sg_remote/connections | sort
###      echo
###      echo "Tunnel Ports:"
###      sqlite3 -separator ',' ~sg_remote/receivers.sqlite "select serno,tunnelPort from receivers where tunnelPort in (`netstat -n -l -t 2>/dev/null | grep 127.0.0.1 | gawk '{split($4, A, /:/); pn=0+A[2]; if (pn >= 40000 && pn < 50000) {x = x (x ? \",\" : \"\") pn}}END{print x}'`)" | sort
###  fi
