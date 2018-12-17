## Networked Receivers ##

Sensorgnomes with network access can connect directly to
sensorgnome.org to have their raw data processed by the tag finder.
All server-side scripts mentioned below are part of the
[motusServer package](https://github.com/jbrzusto/motusServer).

### Self-registration ###
 - on first boot with an ethernet connection, an SG
makes an ssh connection to sensorgnome.org port 59022
 - in exchange for its serial number, it receives a public/private ssh key pair
and a tunnel port (see the section `SSH Server...` below)
 - the key pair is valid for ssh to sg_remote@sensorgnome.org port 59022,
and permits two actions:
   - map the tunnel port on sensorgnome.org to port 22 on the SG
   - run a script called `sg_remote` on sensorgnome.org which receives messages
     from the SG about device addition/removals, GPS fixes, and detections by
     the SG's on-board tag detector
 - self-registration often happens at compudata.ca, who assemble and sell
   sensorgnomes, but can also happen with user-built units

### Network Data Sync ###

Each networked sensorgnome (*SG*) is periodically sync'd with the server
like so:

 1. `syncServer` (an R process running`motusServer::syncServer()`)
   watches the `SYNC` folder (`/sgm_local/sync`)

 2. when a file is written to `SYNC`,  if its name is a receiver serial number `SERNO`
  (e.g. SG-0816BBBK03AF) then `syncServer` creates a new processing job of type
  `syncReceiver` and adds it to the priority queue

 3. an idle, priority `processServer` (R process running `motusServer::processServer()` with
  queue number >= 100) claims the job

 4. `processServer` uses `rsync` to update the contents of `/sgm/file_repo/SERNO`, fetching
 only those files with the correct receiver serial number, and which are new or have grown
 since the previous sync (or manual data upload)

 5. `processServer` then creates a new job of type `newFiles` whose job folder contains
symlinks to all of the new or updated files copied from the receiver in step 4

 6. `processServer` runs the `newFiles` job, which invokes the tag finder on each boot session
 covered by the new files, typically running it with the `--resume` option if the new files
 are all later than the last point at which the boot session was processed.  This will
 generate one new batch of data per processed boot session.  Batches created with the `--resume`
 option might extend runs created in previous batches for the same boot session.

 ### Triggering a Sync ###

 This section explains how serial-number files are written to `SYNC` (see step 2, above).

 - SG connects via ssh to `sg_remote@sensorgnome.org:59022`

 - the ssh server on sensorgnome.org runs the script `sg_remote` to record receiver
   status messages

 - `sg_remote` touches an empty file called `/sgm/remote/connections/SERNO` to indicate the
   SG is connected via ssh

 - `sg_remote` calls the script `syncAttachedReceiver.sh` with parameter `SERNO`

 - `syncAttachedReceiver.sh` works like so:

   - if the receiver is no longer connected, as indicated by a missing `/sgm/remote/connections/SERNO`,
     then exit

   - if called without `WAITLO` or `WAITHI` parameters (e.g. the first time during an SG
     ssh session), set these to 30 and 90 minutes respectively, and **do not** trigger a sync

   - otherwise, trigger a sync by deleting then touching the empty
     file `SERNO` in the watched `SYNC` folder (see step 2 in the previous section).

   - generate a uniformly-distributed random number `WAIT` between
     `WAITLO` and `WAITHI` (so averaging 60)

   - launch an `at` job to re-run the `syncAttachedReceiver.sh` script at the present time plus
     `WAIT` minutes (so averaging 1 hour from now)

   - record the `at` job ID in `/sgm/remote/atjobs/SERNO` (the script deletes any pre-existing
     at job there)

In summary, while a receiver is connected to sensorgnome.org via ssh, a data sync is run on average
every 60 minutes, but no sooner than 30 minutes from the time of initial connection.
The randomized interval between sync jobs is to smooth out the load on the server from syncing
multiple networked receivers.

### Move to New Server ###

A few issues:
- SG software is set to connect to sensorgnome.org:59022

  - we could push out a software update changing that to sgdata.motus.org:59022
  - alternatively, can we just map port 59022 from sensorgnome.org to sgdata.motus.org port 59022?

- we run a patched ssh server on port 59022, which allows us to tighten remote
  port mapping so that a given client can only map their one alloted tunnel port on
  the server.  This needs updating to the latest openssh.

### SSH server for networked sensorgnome receivers ###

This is a fork of openssh's sshd which supports a new option for keys
in the authorized_keys file: `single_remote_forwarding_port=N`, which
means the client connecting using that key can only map a single
remote (i.e. server) port, namely the one specified as `N`.  This is
used to give each sensorgnome a unique tunnel port (in the range
40000...65535 ).  When the SG connects to the server, it will map the
tunnel port on the server back to its own ssh server on port 22.  This
lets us ssh into the SG, without requiring that the SG's ssh server
listen on any external network interfaces, and without any firewall
openings required on the SG's network.  (The SG must of course be
able to reach our server with an outgoing ssh connection to
port 59022 on sensorgnome.org  or sgdata.motus.org )

e.g. The Old Cut sensorgnome SG-5113BBBK2972 has tunnel port 40407.
When connected to the server, it can be reached from the server
by doing:

```
ssh -p 40407 bone@localhost

```

(and then entering the password `bone`).
