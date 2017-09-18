# documentation requiring compilation into a presentation view:
#
# create the data item modelLotekTagLifeSpan.rda and the .pdf
# from modelLotekTagLifeSpan.Rmd
#

all: modelLotekTagLifeSpan.pdf modelLotekTagLifeSpan.rda tags_view_graph.pdf data_flow.pdf

%.pdf %.rda: %.Rmd
	Rscript -e "library(rmarkdown);render(commandArgs(TRUE)[1])" $<

%.pdf: %.dot
	dot -Tpdf $< -o $@
