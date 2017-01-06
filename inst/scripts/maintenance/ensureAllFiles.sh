#!/bin/bash

# make sure every sensorgnome file on the server has been merged

TARG=/sgm/conf_files
SOURCES="/raid3tb /raid5tb"

for s in $SOURCES; do
    find $s  -type f -size +0 -regextype posix-extended -regex "^.*-[a-zA-Z0-9]{4}*BB[a-zA-Z0-9]{6}-[0-9]{6}-[0-9]{4}-[0-1][0-9]-[0-3][0-9].*txt(.gz)$" >> /tmp/allsgfiles.txt
done

for s in $SOURCES; do
    find $s -type f -size +0 -regextype posix-extended -regex "^.*((DTA)|(dta)$)" >> /tmp/allltfiles.txt
done
