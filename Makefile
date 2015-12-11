pkg: 
	R -e 'library(roxygen2); roxygenize("package")'
	R CMD build package
	R CMD INSTALL motus_*.tar.gz
