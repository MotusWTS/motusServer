### Using the Motus Upload and Job Status Pages (2018 - new server) ###


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
these processing jobs.

After selecting `Continue`, the upload server will attempt to queue
each file for processing.  At this point, any file whose contents
are identical to a previously uploaded file will be refused.
To have a file reprocessed, contact motus.org.  Don't upload the
same file more than once!  (there is no harm in uploading individual
raw receiver files more than once if you accidentally create overlapping
archives)


New status site:

   https://sgdata.motus.org/status

Transition to new server:

1. All new uploads should happen via the page above, effective now.
There are a few files uploaded today on the old server (and one or
two currently being uploaded) which still need to be replayed
on the new server, but I'll take care of that shortly.  Any error
messages about processing on the old server are obsolete, except
possibly for those relating to tag registration, since replaying
those registrations would have mostly failed on the new server,
due to the tags already having been registered with motus.

Some 10% or so of uploads processed on the new server since August ran
into some bug or another, so there's still lots to do to have all
data fully available, but it will all happen on the new server.

2. The "manage files" and "files upload" pages on the upload
site above have buttons which link to the status for the job
that processed the file.  This works for files going back
to late August 2017.  For uploads from before that, I might
be able to reconstitute the information, but those files were
not transferred to the new server; rather, the individual
receiver files were moved over.

2. Networked receivers; these are for now still being synced on
the old server.  There are two jobs here:

   2a. process all missing data from networked servers on the new
       server

   2b. move the sync process from the old server to the new one.

   2c. the realtime status page needs to be reconstituted on the
       new machine.

3. Navigating on the new server

 - the "Upload" and "Manage files" pages on the new status server include
   buttons that link to the appropriate status page.  So if you upload
   a file, you get a way to click through to the status page for that
   file.  You can also optionally get an email when a processing job
   completes.

 - the upload server will let you upload a duplicate file, but will then



On Mon, Jan 8, 2018, at 14:37, Denis Lepage wrote:
> Thanks John.
>
> As we discussed a while back, we are planning to move the upload tools
> to Motus, but I expect that it will take several weeks to sort out.
>
> We should also plan to have more details of the processing status
> available from the Motus page. What I am hoping for is a way for us to
> show users the status of each upload, so they can determine themselves
> whether their files are part of the ones that failed.
>
> Here's what I am envisioning. Once we have files uploaded through Motus,
> there would be a page on the Motus site showing the list of files that
> people have uploaded, and the processing status: pending, failed,
> completed (with number of batches/hits). I expect it may be possible for
> some batches within a file to be completed while others fail, so the
> status may need to give a breakdown by batch (number of pending/failed/
> completed batches for each file, rather than a single value).
>
> 1. we generate an upload ID that we somehow communicate to the Linux
> server. One option could be to make it available as part of the file
> name that we put on the shared drive. The other would be to create an
> API entry point that the tag finder can query. IE: return the upload ID
> for a given file name once it's found on the shared drive.
>
> 2. As a minimum, the upload ID would be added to the batch table and
> returned by the SG API, so we can link them to the original upload
> event. It might be useful to be able to separate uploads that have
> failed vs. those that are pending processing. One way to do this may be
> to have a way to query the status of a specific upload in the SG API. If
> we only rely on successful batches, the user would not have a way to
> assess whether an upload has more data being held or still being
> processed.  Rather than a pull (from Motus) process, which would require
> many ping requests until the status was finalized, it might be worth
> thinking about having the SG server inform the Motus database of the
> status linked to each uploadID. I.E., have a Motus API entry point that
> accepts an uploadID, a list of batchID's and their respective statuses.
>
> 3. There's also the question of how to report on networked receivers,
> which wouldn't have an uploadID generated by the Motus database.
>
> Can we think about this soon?
>
> Thanks
> Denis
>
> -----Original Message-----
> From: john brzustowski [mailto:jbrzusto@fastmail.fm]
> Sent: 08 Jan 2018 12:40
> To: Denis Lepage; Stuart Mackenzie; Phil Taylor; Zoe Crysler; Tara Crewe
> Subject: Re: Resend: motus data processing status
>
> Arrg.  My stupid webmail client is truncating messages.
>
> Here's another try:
>
> 1. all uploads from last year have been run against the new server.
> Roughly 1 in 10 ran into problems, which I'll work through and rerun.
> Problems are generally bugs, so once fixed in one instance, should be
> done.
>
> 2. I'm working on getting the upload page moved to the new server and
> integrated with changes there.  Once that's done, all new uploads will
> go directly to the new server and run there.
>
> 3. The uploads from 2018 will get replayed against the server.
>
> 4. Networked receivers need to have syncing done against the new
> server.
>
> I'm aiming to have 1, 2, 3 done by the end of the week.
> 4 will take at least another week after that.
>
> Cheers,
>
> John


--
#-----------------------------------
#  John Brzustowski
#  Wolfville, NS  Canada
