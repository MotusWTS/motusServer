all: Sqlite_Compression_Extension.so tags_view_graph.pdf

Sqlite_Compression_Extension.so: Sqlite_Compression_Extension.c
	gcc -I. -fPIC -O3 -shared $< -o $@ -lbz2

tags_view_graph.pdf: tags_view_graph.dot
	dot -Gnodesep=1.5 -Gsplines=true -Tpdf $< -o $@
