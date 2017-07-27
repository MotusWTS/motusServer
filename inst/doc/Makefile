# odd jobs:
#
# create the data item modelLotekTagLifeSpan.rda and the .pdf
# from modelLotekTagLifeSpan.Rmd
#

%.pdf %.rda: %.Rmd
	Rscript -e "library(rmarkdown);render(commandArgs(TRUE)[1])" $<

all: modelLotekTagLifeSpan.pdf modelLotekTagLifeSpan.rda
