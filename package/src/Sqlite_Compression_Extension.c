/*
  Adapted from Levent Serinol's zlib compression extension to sqlite3:

  https://sites.google.com/site/lserinol/sqlitecompress

  and combined with SQLite's own fileio extension from:

  http://www.sqlite.org/src/artifact?ci=trunk&filename=ext/misc/fileio.c

*/
  
#include <stdio.h>
#include <stdlib.h>
#include <sqlite3ext.h>
#include <bzlib.h>
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

  int append = argc > 2 && sqlite3_value_int(argv[2]) > 0;

  zFile = (const char*)sqlite3_value_text(argv[0]);
  if( zFile==0 ) return;
  out = fopen(zFile, append ? "ab" : "wb");
  if( out==0 ) return;
  z = (const char*)sqlite3_value_blob(argv[1]);
  if( z==0 ){
    rc = 0;
  }else{
    rc = fwrite(z, 1, sqlite3_value_bytes(argv[1]), out);
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

static void compressFunc (sqlite3_context *context, int argc, sqlite3_value **argv ) {
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
  BZ2_bzBuffToBuffCompress( outBuf, &nOut, inBuf, nIn, 9, 0, 0);
  sqlite3_result_blob(context, outBuf, nOut, free);
}

static void uncompressFunc ( sqlite3_context *context, int argc, sqlite3_value **argv ) {
  // JMB: unlike the original function, this function requires a second paramter
  // giving the uncompressed size.

  unsigned int nIn, nOut, rc;
  unsigned char *inBuf;
  unsigned char *outBuf;
  unsigned int nOut2;

  assert( argc==2 );
  nIn = sqlite3_value_bytes(argv[0]);
  inBuf = (unsigned char *) sqlite3_value_blob(argv[0]);
  nOut = sqlite3_value_int(argv[1]);
  outBuf = malloc( nOut );
  rc = BZ2_bzBuffToBuffDecompress(outBuf, &nOut, inBuf, nIn, 0, 0);
  if ( rc!=BZ_OK ) {
    free(outBuf);
  } else {
    sqlite3_result_blob(context, outBuf, nOut, free);
  }
}



int sqlite3_extension_init(
                           sqlite3 *db,
                           char **pzErrMsg,
                           const sqlite3_api_routines *pApi
                           ) {
  SQLITE_EXTENSION_INIT2(pApi);
  sqlite3_create_function(db, "bz2compress", 1, SQLITE_UTF8, 0, &compressFunc, 0, 0);
  sqlite3_create_function(db, "bz2uncompress", 2, SQLITE_UTF8, 0, &uncompressFunc, 0, 0);
  sqlite3_create_function(db, "readfile", 1, SQLITE_UTF8, 0, readfileFunc, 0, 0);
  sqlite3_create_function(db, "writefile", 3, SQLITE_UTF8, 0, writefileFunc, 0, 0);
  return 0;
}
