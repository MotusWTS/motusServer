<?php

/* run a php script from the command line, including get/post args and session cookies


               ! ! !  W  A  R  N  I  N  G  ! ! !
               ! ! !  W  A  R  N  I  N  G  ! ! !
               ! ! !  W  A  R  N  I  N  G  ! ! !

   ! ! !  DO NOT INSTALL THIS SCRIPT IN A WEB-ACCESSIBLE LOCATION  ! ! !

               ! ! !   YOU'VE BEEN WARNED  ! ! !


   Usage:
   php5 debug.php SCRIPT PHPSESSID AUTHTOKEN GET_ARGS POST_ARGS

   with:

   SCRIPT  = path to the .php script you want to run
   PHPSESSID = string giving PHPSESSID cookie, or '-' for none
   AUTHTOKEN = string giving authtoken cookie, or '-' for none
   GET_ARGS = json-encoded GET args, or '-' for none
   POST_ARGS = json-encoded POST args, or '-' for none

   Refs:
   http://stackoverflow.com/questions/5655284/how-to-pass-parameters-from-command-line-to-post-in-php-script#17724485
   http://stackoverflow.com/questions/7578595/is-it-possible-to-read-cookie-session-value-while-executing-php5-script-through#7578766

 */

/* require a that we be starting from the command line */

if (!isset($_SERVER["HTTP_HOST"])) {
    $_SERVER = array();
    $_SERVER["HTTP_HOST"]="sensorgnome.org";
    $_SERVER["REQUEST_URI"]="/upload/$argv[1]";
    $_SERVER["REMOTE_ADDR"]="127.0.0.1";

    $_COOKIE = array();
    if ($argc > 2 && $argv[2] != '-')
        $_COOKIE["PHPSESSID"] = $argv[2];
    if ($argc > 3 && $argv[3] != '-')
        $_COOKIE["authtoken"] = $argv[3];

    if ($argc > 4 && $argv[4] != '-')
        $_GET = json_decode($argv[4], true);
    else
        $_GET = array();

    if ($argc > 5 && $argv[5] != '-')
        $_POST = json_decode($argv[5], true);
    else
        $_POST = array();

    $_REQUEST = array();

    $_FILES = array();

    if ($argc > 0)
        require($argv[1]);
    else
        echo "No script provided.\n";
}
