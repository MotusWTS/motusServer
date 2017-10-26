#!/bin/bash

# Things to do after installing the motusServer package.
# must be run as a user who has sudo privileges

## make sure scripts are in the right places before trying to
## modify their properties

Rscript -e 'library(motusServer);ensureServerDirs()'

## is there really anything to do here?
