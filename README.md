# motusServer

R package to operate a server to process data for http://motus.org
This package processes raw data from receivers and stores results in
a master database.

**Motus users** should not use this package. User data can be accessed either through the motusClient (https://github.com/MotusWTS/motusClient) using the Motus rPackage (documented here: https://motus.org/MotusRBook/) or downloaded directly from the motus platform website: https://motus.org/data/downloads

This server obtains its data from the server above, so there may be a small
time lag before the same data are available.

In order to setup a new test environment, you need to install vagrant, available from https://www.vagrantup.com/downloads.html. Once it is installed, and you have cloned this repostory, you can start up your environment with the command

* vagrant up

You can log into the instance with the command

* vagrant ssh

When you are done, you can shutdown the instance with

* vagrant halt

If you need to get rid of the instance, you can delete it with the command

* vagrant destroy
