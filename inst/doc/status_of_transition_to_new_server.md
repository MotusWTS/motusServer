### Status of Transition to New Server ###

1. All files succesfully uploaded to the old server have now been
replayed against the new server.

2. Some 10% or so of uploads processed on the new server since August ran
into one bug or another, so there's still lots to do to have all
data fully available, but it will all happen on the new server.
Error reports of jobs run on the old server are now obsolete.

3. Uploading to the old server has been disabled, with users now
directed to the upload page on the new server.

4. Networked receivers have not been synced to the new server.
Doing so will happen in these steps:

  - in the next few days, each receiver's files on the old server
    will be synced to the new server and re-run.

  - daily re-syncs from each networked receiver to the new server,
    using the old server as an ssh proxy (via port-mapping) will be
    set up

  - a new scheme for "partial" batches will be established so that
    hourly syncing of networked receivers doesn't generate an unmanageable
    number of batches

  - a software update will be sent to networked receivers which well let
    them sync directly to the new server, bypassing the old one.

Full completion may take a couple of weeks.

### Using the Motus Upload and Job Status Pages (new server) ###

## Uploading Files from Receivers ##

To upload files for processing on the new server, login with motus credentials here:

   https://sgdata.motus.org/upload

You can drag or select files to add to the window.  Files you upload can be
of these types:

 - .zip, .rar, or .7z archives of raw .txt and .txt.gz files from one or more
   sensorgnome receivers, and/or .DTA files from one or more Lotek receivers

 - individual .DTA files from Lotek receivers

 - .zip, .rar,  or .7z archives with tag recordings and a `tagreg.txt` metadata
   file for tag registration

Each file you upload becomes its own processing job.  You might want to upload
one archive file per receiver, although this isn't required.

After using `Add Files` to select files for uploading, hit `Upload
Files` to begin the upload process.

Once files have been uploaded, you need to assign a motus project ID
for each one.  This determines ownership of the files in cases where
we don't already have deployment records for receivers.  You will be
shown a list of the projects to which your credentials permit access.

You can also choose whether to receive an email notification for
these processing jobs.  The email will be sent to the address
associated with your login credentials at motus.org

After selecting `Continue`, the upload server will attempt to queue
each file for processing.  At this point, any file whose **contents**
are identical to a previously uploaded file will be refused.
To have a file reprocessed, contact motus.org; uploading the
same file more than once!  (there is no harm in uploading individual
raw receiver files more than once if you accidentally create overlapping
archives; we just don't want huge uploads being repeated.

For each file, there is a status button that links to the
status web page, which will show how the job is progressing.

## Data Processing Status Site ##

   https://sgdata.motus.org/status

This page lists jobs you have permission to view.  This will
include all uploads since ~ August 20, 2017.  Files uploaded
prior to that are not listed here, but their contents should
already have been processed.

Features:

- click on a job summary line to pop up a window with details
  on sub jobs

- click on a subjob ID to jump to its log

- click on a receiver serial number to pop up a window summarizing
  that receiver.  For an SG, the summary shows how many files are
  stored, by day.  Normally, a file is stored in the filesystem
  repository, and a record of it appears in the receiver's database.
  If there are discrepancies in the counts of such files, the day
  is shown in an error colour.  Such discrepancies are bugs, and
  should be reported.

- click on a receiver day to pop up a window of all files for that
  receiver and day.

- in the files list, you can click on a jobID to go to the job in
  which that file was processed.

## Summary Product Download Site ##

   https://sgdata.motus.org/download

Users visiting the old site will be told to come to this one,
but can also find a link to the now obsolete old download site.
