<?php
/***

   This script is called when authentication using motus credentials
   is required.

   - when called without GET parameter `login_form_user`, display a
   login dialog

   - when called with GET parameter `login_form_user`, check the
   submitted username and password against motus.org.  If valid,
   return a cookie for use by apache's mod-auth-tkt.  The cookie
   will contain a list of tokens (motus project IDs) providing
   access to files as appropriate.  If the request has GET parameter
   `back`, then successful authorization will redirect to the
   URL-encoded page given by that.

 ***/

/////////// CUSTOMIZATION SECTION ////////////////
// A random secret key obtained like so:
//
//    head -64c /dev/urandom | base64 --wrap=0
//
// The same secret key must be added as the line
//
//    TKTAuthSecret "..."
//
// in the file /etc/apache2/mods-available/auth_tkt.conf replacing
// ... with the value of $SECRET_KEY below.
//
$SECRET_KEY = file_get_contents("/etc/apache2/sites-available/000-default-le-ssl.conf");
$SECRET_KEY = preg_replace('/(?s).*TKTAuthSecret "/', '', $SECRET_KEY);
$SECRET_KEY = preg_replace('/(?s)".*/', '', $SECRET_KEY);

//
// URL to which we redirect after a successful login if 'back' isn't specified.
//
$DEFAULT_URL = 'https://sgdata.motus.org/download';
//
// URL for validating a user,password pair:
$MOTUS_VALIDATE_USER_API = "https://motus.org/api/user/validate";
//
//
/////////// END CUSTOMIZATION SECTION ///////////

// is a login form needed?
$need_login_form = true;

// additional message to provide user before prompting for login
$error_message = '';

// HTTP headers to guarantee no caching
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
header("Cache-Control: no-store, no-cache, must-revalidate");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");

// Function to generate a cookie compatible with mod-auth-tkt.

// Adapted from this file, which is included in debian package libapache2-mod-auth-tkt:
//
//####################################################################
//
// File: auth_ticket.inc.php
//
// By:   Luc Germain, STI, Universite de Sherbrooke
// Date: 2004-02-17
//
//#####################################################################
//
//#####################################################################
//
// This file defines functions to generate cookie tickets compatible
// with the "mod_auth_tkt" apache module.
//
//#####################################################################


//---------------------------------------------------------------
// $result = getTKTHash( $ip, $user, $tokens, $data, $key)
//---------------------------------------------------------------
//
// Returns a string that contains the signed cookie.
//
// The cookie includes the ip address of the user, the user UID, the
// tokens, the user data and a time stamp.
//
//---------------------------------------------------------------

function getTKTHash( $ip, $user, $tokens, $data, $key) {

    // set the timestamp to now
    // unless a time is specified
    $ts = time();
    $ipts = pack( "NN", ip2long($ip), $ts );

    // make the cookie signature
    $digest0 = md5( $ipts . $key . $user . "\0" . $tokens . "\0" . $data );
    $digest = md5( $digest0 . $key );

    if( $tokens ){
        $tkt = sprintf( "%s%08x%s!%s!%s", $digest, $ts, $user, $tokens, $data);
    } else {
        $tkt = sprintf( "%s%08x%s!%s", $digest, $ts, $user, $data);
    }
    return( $tkt );
}

if (isset($_GET['unauth'])) {
    $error_message = "You are not authorized for this project.<br>Maybe login with different credentials?";
}

if (isset($_GET['login_form_user'])) {
    $login_form_user    = $_GET['login_form_user'];
    $login_form_pass	= $_GET['login_form_pass'];

    /** validate directly against motus.org **/

    $ch = curl_init($MOTUS_VALIDATE_USER_API);
    $params = '{"date":"' . gmdate('YmdHis', time()) . '","pword":"' . stripslashes($login_form_pass) . '","login":"' . $login_form_user . '"}';
    $json = 'json=' . urlencode($params);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, 0);
    curl_setopt($ch, CURLOPT_POSTFIELDS,  $json);
    $res = curl_exec($ch);
    curl_close($ch);
    $data = json_decode($res, true);
    if (! $data) {
        // in case motus is returning Windows-1250
        $res = iconv("Windows-1250", "UTF-8", $res);
        $data = json_decode($res, true);
    }
    if (! $data) {
        // in case motus is returning Windows-1252
        $res = iconv("Windows-1252", "UTF-8", $res);
        $data = json_decode($res, true);
    }
    if (! isset($data['errorCode'])) {
        $tokens = implode(',', array_keys($data['projects']));
        $addr = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : "0.0.0.0";
        $cookie = getTKTHash($addr, $login_form_user, $tokens, null, $SECRET_KEY);
        $need_login_form = false;
        header("Location: " . (isset($_GET['back']) && $_GET['back'] != '' ? $_GET['back'] : $DEFAULT_URL));
        setcookie('auth_tkt', $cookie, time() + 60*60*24*30, '/');
        exit;
    } else {
        $error_message = "<br><center><b>Invalid login</b></center><br>";
    }
}
if ($need_login_form) {
?>
    <html>
        <head>
            <title>Motus Data Server Login</title>
        </head>
        <body>
            <dialog open>
                <div id="message"><?php echo $error_message ?></div>
                <h3>Please login using credentials from motus.org</h3>
	        <form action="login.php" method="get">
	            <section>
		        <label for="login_form_user">username:</label>
		        <input type="text" name="login_form_user" id="login_form_user" autofocus>
                    </section>
                    <section>
		        <label for="login_form_pass">password:</label>
		        <input type="password" name="login_form_pass" id="login_form_pass"/>
                        <?php
                        print '<input type="hidden" name="back" id="back" readonly value="' . (isset($_GET['back']) ? $_GET['back'] : ''). '"/>';
                        ?>
	            </section>
                    <section>
                        <center>
	                    <button type="submit" name="submit" value="go">Login</button>
                        </center>
                    </section>
	        </form>
            </dialog>
        </body>
    </html>
<?php
}
?>
