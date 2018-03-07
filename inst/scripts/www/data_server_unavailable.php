<?php
$gzip = 0;
if (preg_match("/gzip/i", $_SERVER['HTTP_ACCEPT_ENCODING'])) {
    $gzip = 1;
}
header("Content-Type: application/json");
header("Content-Encoding: " . ($gzip ? "gzip" : "bzip2"));

$message = '{"error":"The motus data server is down for a few hours.  Please try again later."}';
if ($gzip) {
    $out = gzencode($message);
} else {
    $out = bzcompress($message);
}
print $out;
?>
