<?php
$gzip = 0;
if (preg_match("/gzip/i", $_SERVER['HTTP_ACCEPT_ENCODING'])) {
    $gzip = 1;
}
header("Content-Type: application/json");
header("Content-Encoding: " . ($gzip ? " gzip" : "bzip2"));

$message = '{"userID":-1,"authToken":"FAKE TOKEN - SERVER NOT AUTHENTICATING"}';
if ($gzip) {
    $out = gzencode($message);
} else {
    $out = bzcompress($message);
}
print $out;
?>
