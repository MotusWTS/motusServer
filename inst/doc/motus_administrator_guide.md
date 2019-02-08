### Administrator's Guide to Running a Motus Server ###

John Brzustowski, July 2018

Based on questions sent by Stu Mackenzie.

## User accounts on the server ##

 > Which tasks can only be performed using a properly configured user
 > account, such as "sg"?

The folder `/sgm/bin` contains motus-related commands.  This folder is
prepended to the user's path when logging Most
of these can be executed with the option `-h`, to print a usage message.

e.g. the main script of interest starts all motus-related server
processes:

```bash
/sgm/bin/runAllMotusServers.sh -h
Usage: runAllMotusServers.sh [-h] [-s] [N]

Run all motus servers by invoking these scripts:

   - runMotusStatusServer.sh
   - runMotusStatusServer2.sh

   - runMotusProcessServer.sh 1
   - runMotusProcessServer.sh 2
     ...
   - runMotusProcessServer.sh N
   - runMotusProcessServer.sh 101
   - runMotusProcessServer.sh 102
   - runMotusSyncServer.sh

Defaults to N=4.

Specifying -h gives this message.

Specifying -s forces deletion of all entries in the server\'s symLocks table.
This should be used at boot time, and only at boot time, to delete stale locks
from an unclean shutdown (e.g. power outage).
```

Other commands of interest (assuming /sgm/bin is on the user's`\$PATH`)

 > Can other user accounts be configured to do the same tasks? If so,
 > how? If not, what is the password for sg?

In order to maintain consistent file ownership and permissions, the
motusServer processes must be always be run as the same user, which on
the current server is `sg`.  Any user with `sudo` privileges can
switch her login session to that user by doing `sudo su sg`.  A user
`someone` can be added to the `sudo` group by someone already in that
group by the latter doing `sudo usermod -a -G sudo someone`.

Alternatively, a user's public SSH key can be appended to the file
`/home/sg/.ssh/authorized_keys`, which will permit the user to ssh in
as user `sg`.  For example, if user `someone` is already set up to
login via ssh on the server, than anyone in the `sudo` group can
authorize that person to ssh in as user `sg` by doing `sudo cat
/home/someone/.ssh/id_*.pub >> /home/sg/.ssh/authorized_keys`

## Updates ##

 > What is the procedure to rebuild motusServer and install it on
 > sgdata.motus.org?


```bash
## to rebuild the motusServer package after changes to source
sudo su sg # if not already logged in as user `sg`
cd ~/src/motusServer
# runs the script /sgm/bin/rpack which
# - regenerates the roxygen-based documentation for the package
# - rebuilds the package
# - re-installs the package
# Errors will abort this process, leaving the current version
# in place.
rpack -g .

## running servers continue to user the previous version until
## restarted, so after the above completes successfully, do:
/sgm/bin/killAllMotusServers.sh
/sgm/bin/runAllMotusServers.sh
```

 > What is the procedure to rebuild find_tags and install it on
 > sgdata.motus.org?

```bash
sudo su sg # if not already logged in as user `sg`
cd ~/src/find_tags
# make sure you are on the correct branch
git checkout master
cd src
# rebuild from scratch, using two cores
make clean; make -j 2 find_tags_motus
sudo make install # install in /sgm/bin
```
There is a second version of the tag finder called `find_tags_unifile` that
is used on the SGs themselves, and to register tags on the server.  This is
rebuilt like so:
```bash
# if not already logged in as user `sg`
sudo su sg
cd ~/src/find_tags
# switch to the separate branch for this version
git checkout find_tags_unifile
make clean; make -j 2 find_tags_unifile
```

Are there library dependencies which we should be aware of? Can/should we run apt update/upgrade regularly? R update.packages()?

Restarting:

When should the motusServer processes be restarted, and how should it be done?

When the sgdata server is restarted, what (if anything) needs to be done to get everything running again?

If we were to migrate to a new physical server or set up a test/development server, what would we have to set up on the new server? Which files should or shouldn't be copied to new servers?

Parameters:
What is the procedure to add a new duplicate receiver serial number?

What is the procedure to add a new tag model?

What's the procedure to change the default parameters for a receiver? For a project?

Is there a way to set parameters for one deployment of a particular receiver but not another (the noisy site problem)?

How do we decide what a receiver's parameters should be?

What other parameters should we expect to have to modify, and how, why, etc.?

Errors:

When should a job be re-run, and how should it be done?

When a job that previously stopped due to an error is rerun after the cause of the error is fixed, sometimes it generates the message "There were no new files in the dataset, so I didn't do anything.", even though the files weren't processed due to the error. What should be done in this case?

When should a file be re-uploaded by a user?

If a file is uploaded to the wrong project, how should that be corrected?

When should a receiver be re-run, and how should it be done?

When a receiver is re-run, do any email notifications get sent? Are earlier detections and other products deleted?

Are there other manual interventions we should expect to have to perform, and what are the procedures for them?

Batches:

We have some batches with the same deviceID and monoBN that do not have overlapping tsBegin and tsEnd, but have large gaps (e.g. >= 1 year) between the end of one batch and the start of the next. Is this expected?

What is the best way to identify duplicate batches? We have pairs of batches with the same deviceID and overlapping tsBegin and tsEnd, where some pairs have the same monoBN and others have different monoBN. Sometimes both tsBegin and tsEnd are identical, sometimes one or the other is different, and sometimes they're both different.

Miscellaneous:

Can the files in the trash directory be safely deleted? (There are currently (May 25th) ~134GB of files in the trash directory, 129GB of which are more than a month old, compared to 8.8TB in /sgm with 5.3TB free on the partition. So space isn't really a concern, just the non-UTF8 filename bug.)

Outstanding ?: How are internet-connected receivers going to be, or are being handled in terms of data transfer to sgdata?


Development:

What are the most important bugs you're aware of?

Are there any particular quirks of the architecture which bother you, or are likely to surprise us?

What are the most important missing features, in the pipe or in your head, that you want to see done, and what’s the basic roadmap for their completion? Some/most of these may already be documented somewhere, so we should make sure we know where and understand what we can.
e.g.	frequency override as discussed?
Storing and managing CTT LifeTag data?
Connected receivers – data flow and updates?
