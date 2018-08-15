### motusServer Root Filesystem Overlay ###

The `motusServer` package provides some files which must be installed outside
the usual R package tree.  This file documents those files, and provides
the required ownership and permission information in a form accepted by
`motusServer:::postInstall()`.  Any line in this file which begins with
a percent sign (**%**) is parsed by that function as white-space separated
items `USER GROUP PERMISSIONS PATH` where:

 - `USER` and `GROUP` are the desired symbolic file owner and group
 - `PERMISSIONS` is the desired file permission string, in octal format
 - `PATH` is the path to the file relative to root

The files to be installed are in the `inst/root` tree of the package repo, with
generic ownership and permissions.

For example, the line `% root root 644 /etc/ssh/sshd_sg_config` indicates the
file `inst/root_overlay/etc/ssh/sshd_sg_config` will be copied to `/etc/ssh/sshd_sg_config`,
its ownership will be `root:root`, and its mode will be 644 (rw-r-r-).

Here are the files:

```
% root root 644 /etc/apache2/sites-available/001-sgdata-ssl.conf
% root root 644 /etc/apache2/sites-available/002-sgdata-nossl.conf
% root root 644 /etc/cron.d/refreshMotusMetaDB
% root root 644 /etc/cron.d/sqlite_daily_backup
% root root 644 /etc/cron.d/monthly_trash_dump
% root root 755 /etc/init.d/sshd-sg

```
And here are symlinks we need to connect some external programs to content
provided by this package.  These are given as `% src -> dst`

```
# download directory
% /var/www/html/download -> /sgm/www
% /var/www/html/index.html -> /sgm/www/index.html
% /var/www/html/index.php -> /sgm/www/index.php

# ugly php login page
% /var/www/html/login.php -> /sgm/www/login.php

# public pages not requiring login
% /var/www/html/public -> /sgm/pub

# additional message for status page
% /var/www/html/status_message.html -> /sgm_local/bin/www/status_message.html

# upload pages (yes, directly from the source folder.  Not smart!)
% /var/www/html/upload -> /home/sg/src/ProjectSend

# robots.txt - keep webcrawlers off this server; at most, the /sgm/pub folder would
# be worth indexing, but there should be other links to all that content elsewhere.
% /var/www/html/robots.txt -> /sgm_local/bin/www/robots.txt

```

Commands to enable use of some files etc.

```
# enable the two websites (nossl simply redirects to ssl)
%! sudo a2ensite 001-sgdata-ssl
%! sudo a2ensite 002-sgdata-nossl

# restart the web server gracefully
%! sudo apachectl graceful

```