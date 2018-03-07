all: Sqlite_Compression_Extension.so

Sqlite_Compression_Extension.so: Sqlite_Compression_Extension.c
	gcc -I. -fPIC -O3 -shared $< -o $@ -lbz2 -lz
