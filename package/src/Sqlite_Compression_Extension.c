/*
  Adapted from Levent Serinol's zlib compression extension to sqlite3:

     https://sites.google.com/site/lserinol/sqlitecompress
*/
  
#include <stdlib.h>
#include <sqlite3ext.h>
#include <zlib.h>
#include <assert.h>
SQLITE_EXTENSION_INIT1

static void compressFunc( sqlite3_context *context, int argc, sqlite3_value **argv){
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

static void uncompressFunc( sqlite3_context *context, int argc, sqlite3_value **argv){
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
){
  SQLITE_EXTENSION_INIT2(pApi)
  sqlite3_create_function(db, "mycompress", 1, SQLITE_UTF8, 0, &compressFunc, 0, 0);
  sqlite3_create_function(db, "myuncompress", 1, SQLITE_UTF8, 0, uncompressFunc, 0, 0);

  return 0;
}
