/*
  Adapted from Levent Serinol's zlib compression extension to sqlite3:

  https://sites.google.com/site/lserinol/sqlitecompress

  and combined with SQLite's own fileio extension from:

  http://www.sqlite.org/src/artifact?ci=trunk&filename=ext/misc/fileio.c

  changes:

  - add bzip2/bunzip2 support
  - add ability to decompress gzip files (strip header; use trailing 4-byte size)
  - reinstate gzcompress, gzuncompress

*/

#include <stdio.h>
#include <stdlib.h>
#include <sqlite3ext.h>
#include <bzlib.h>
#include <zlib.h>
#include <assert.h>
SQLITE_EXTENSION_INIT1

/*
** 2014-06-13
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
******************************************************************************
**
** This SQLite extension implements SQL functions readfile() and
** writefile().
*/

/*
** Implementation of the "readfile(X)" SQL function.  The entire content
** of the file named X is read and returned as a BLOB.  NULL is returned
** if the file does not exist or is unreadable.
*/
static void readfileFunc(
                         sqlite3_context *context,
                         int argc,
                         sqlite3_value **argv
                         ) {
  const char *zName;
  FILE *in;
  long nIn;
  void *pBuf;

  zName = (const char*)sqlite3_value_text(argv[0]);
  if( zName==0 ) return;
  in = fopen(zName, "rb");
  if( in==0 ) return;
  fseek(in, 0, SEEK_END);
  nIn = ftell(in);
  rewind(in);
  pBuf = sqlite3_malloc( nIn );
  if( pBuf && 1==fread(pBuf, nIn, 1, in) ){
    sqlite3_result_blob(context, pBuf, nIn, sqlite3_free);
  }else{
    sqlite3_free(pBuf);
  }
  fclose(in);
}

/*
** Implementation of the "writefile(X,Y)" SQL function.  The argument Y
** is written into file X.  The number of bytes written is returned.  Or
** NULL is returned if something goes wrong, such as being unable to open
** file X for writing.
*/
static void writefileFunc(
                          sqlite3_context *context,
                          int argc,
                          sqlite3_value **argv
                          ){
  FILE *out;
  const char *z;
  sqlite3_int64 rc;
  const char *zFile;
  int len;

  int append = argc > 2 && sqlite3_value_int(argv[2]) > 0;

  zFile = (const char*)sqlite3_value_text(argv[0]);
  if( zFile==0 ) return;
  out = fopen(zFile, append ? "ab" : "wb");
  if( out==0 ) return;
  len = sqlite3_value_bytes(argv[1]);
  z = (const char*)sqlite3_value_blob(argv[1]);
  if( z==0 ){
    rc = 0;
  }else{
    rc = fwrite(z, 1, len, out);
  }
  fclose(out);
  sqlite3_result_int64(context, rc);
}


#ifdef _WIN32
__declspec(dllexport)
#endif
int sqlite3_fileio_init(
                        sqlite3 *db,
                        char **pzErrMsg,
                        const sqlite3_api_routines *pApi
                        ){
  int rc = SQLITE_OK;
  SQLITE_EXTENSION_INIT2(pApi);
  (void)pzErrMsg;  /* Unused parameter */
  return rc;
}

#ifdef DEBUG
static void recorded_free ( void * p) {
  fprintf(stderr, "F: %p\n", p);
  free(p);
};
#endif


static void BZ2compressFunc (sqlite3_context *context, int argc, sqlite3_value **argv ) {
  // JMB: unlike the original function, we don't store uncompressed size, as this is
  // already in our table as a separate field
  unsigned nIn, nOut;
  unsigned char *inBuf;
  unsigned char *outBuf;
  assert( argc==1 );
  nIn = sqlite3_value_bytes(argv[0]);
  inBuf = (unsigned char *) sqlite3_value_blob(argv[0]);
  nOut = 600 + nIn * 1.01;
  outBuf = malloc( nOut );
#ifdef DEBUG
  fprintf(stderr, "A: %p\n", outBuf);
#endif
  BZ2_bzBuffToBuffCompress( outBuf, &nOut, inBuf, nIn, 9, 0, 0);
#ifdef DEBUG
  sqlite3_result_blob(context, outBuf, nOut, recorded_free);
#else
  sqlite3_result_blob(context, outBuf, nOut, free);
#endif
}


static void BZ2uncompressFunc ( sqlite3_context *context, int argc, sqlite3_value **argv ) {
  // JMB: unlike the original function, this function requires a second parameter
  // giving the uncompressed size.

  unsigned int nIn, nOut, rc;
  unsigned char *inBuf;
  unsigned char *outBuf;
  unsigned int nOut2;

  assert( argc==2 );
  nIn = sqlite3_value_bytes(argv[0]);
  inBuf = (unsigned char *) sqlite3_value_blob(argv[0]);
#ifdef DEBUG
  fprintf(stderr, "A: %p\n", inBuf);
#endif
  nOut = sqlite3_value_int(argv[1]);
  outBuf = malloc( nOut );
#ifdef DEBUG
  fprintf(stderr, "A: %p\n", outBuf);
#endif
  rc = BZ2_bzBuffToBuffDecompress(outBuf, &nOut, inBuf, nIn, 0, 0);
  if ( rc!=BZ_OK ) {
    free(outBuf);
  } else {
#ifdef DEBUG
    sqlite3_result_blob(context, outBuf, nOut, recorded_free);
#else
    sqlite3_result_blob(context, outBuf, nOut, free);
#endif
  }
}

/*
** Implementation of the "readgzfile(X, Y)" SQL function.  At most Y bytes of
** uncompressed data are read from the gzip-compressed file named X, and returned as a BLOB.
** NULL is returned if the file does not exist or decompression fails.  If Y is not
** given, the trailing 4-byte suffix of the file is used to determine uncompressed size.
*/

static void GZreadFile( sqlite3_context *context, int argc, sqlite3_value **argv){

  unsigned int nIn;
  int nOut;
  void *inBuf;
  const char *zName;
  FILE *in;
  gzFile gzf;

  zName = (const char*)sqlite3_value_text(argv[0]);
  if( zName==0 ) {return;}

  in = fopen(zName, "rb");
  if( in==0 ) return;
  if (argc < 2) {
    /* get size from 4-byte suffix of file */
    fseek(in, -4, SEEK_END);
    /* danger: assume little-endian int in file suffix and memory! */
    if (1 != fread(&nIn, sizeof(nIn), 1, in)) {
      nIn = 0;
    }
    rewind(in);
  } else {
    nIn = sqlite3_value_int(argv[1]);
  }
  if( nIn > 0 ) {
    gzf = gzdopen(dup(fileno(in)), "rb");
    if (gzf != 0) {
      inBuf = sqlite3_malloc( nIn );
      // WARNING only works for file sizes <= 2^31 bytes
      nOut = gzread(gzf, inBuf, nIn);
      gzclose(gzf);
      if( nOut < 0) {
        sqlite3_free(inBuf);
      } else {
        if ( nOut < nIn) {
          inBuf = sqlite3_realloc(inBuf, nOut);
        }
        sqlite3_result_blob(context, inBuf, nOut, sqlite3_free);
      }
    }
  }
  fclose(in);
}

static void gzcompress( sqlite3_context *context, int argc, sqlite3_value **argv){
  int nIn, nOut;
  long int nOut2;
  const unsigned char *inBuf;
  unsigned char *outBuf;
  assert( argc==1 );
  nIn = sqlite3_value_bytes(argv[0]);
  inBuf = sqlite3_value_blob(argv[0]);
  nOut = 13 + nIn + (nIn+999)/1000;
  outBuf = malloc( nOut+4 );
  outBuf[0] = nIn>>24 & 0xff;
  outBuf[1] = nIn>>16 & 0xff;
  outBuf[2] = nIn>>8 & 0xff;
  outBuf[3] = nIn & 0xff;
  nOut2 = (long int)nOut;
  compress(&outBuf[4], &nOut2, inBuf, nIn);
  sqlite3_result_blob(context, outBuf, nOut2+4, free);
}

static void gzuncompress( sqlite3_context *context, int argc, sqlite3_value **argv){
  unsigned int nIn, nOut, rc;
  const unsigned char *inBuf;
  unsigned char *outBuf;
  long int nOut2;

  assert( argc==1 );
  nIn = sqlite3_value_bytes(argv[0]);
  if( nIn<=4 ){
    return;
  }
  inBuf = sqlite3_value_blob(argv[0]);
  nOut = (inBuf[0]<<24) + (inBuf[1]<<16) + (inBuf[2]<<8) + inBuf[3];
  outBuf = malloc( nOut );
  nOut2 = (long int)nOut;
  rc = uncompress(outBuf, &nOut2, &inBuf[4], nIn);
  if( rc!=Z_OK ){
    free(outBuf);
  }else{
    sqlite3_result_blob(context, outBuf, nOut2, free);
  }
}

int sqlite3_extension_init(
                           sqlite3 *db,
                           char **pzErrMsg,
                           const sqlite3_api_routines *pApi
                           ) {
  SQLITE_EXTENSION_INIT2(pApi);
  sqlite3_create_function(db, "bz2compress", 1, SQLITE_UTF8, 0, &BZ2compressFunc, 0, 0);
  sqlite3_create_function(db, "bz2uncompress", 2, SQLITE_UTF8, 0, &BZ2uncompressFunc, 0, 0);
  sqlite3_create_function(db, "gzreadfile", -1, SQLITE_UTF8, 0, &GZreadFile, 0, 0);
  sqlite3_create_function(db, "readfile", 1, SQLITE_UTF8, 0, &readfileFunc, 0, 0);
  sqlite3_create_function(db, "writefile", 3, SQLITE_UTF8, 0, &writefileFunc, 0, 0);
  sqlite3_create_function(db, "gzcompress", 1, SQLITE_UTF8, 0, &gzcompress, 0, 0);
  sqlite3_create_function(db, "gzuncompress", 1, SQLITE_UTF8, 0, &gzuncompress, 0, 0);
  return 0;
}
