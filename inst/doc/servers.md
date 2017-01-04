# Sketch of motusServer design #

## Principles:

   - atomic completion of jobs and subjobs

   - on interrupt / restart, must be able to resume uncompleted jobs
     and jobSteps (we're not there yet)

   - full details on what has been done and its status

   - easy to read for web server

## Storing state:

   - pure filesystem (e.g. filenames that encode steps, parameters; existing version)
      - pro: persistent, easy to script, atomic,
      - con: have to encode parameters; filenames get long; have to avoid collisions (use timestamps in filenames)

   - .sqlite database in each job directory
      - pro: persistent, atomic, no worries about encoding etc.
      - con: slightly harder to script

   - **master database** in /sgm/server.sqlite; transient files and email messages in file tree
      - pro: everything in one place for queries etc.; atomic
      - con: any?

- incoming emails processed by /sgm/bin/incomingEmail.sh
  - message -> drop carriage returns -> /sgm/inbox/

- emailServer: job is to watch for new messages (via close_write) in /sgm/inbox, then
   create and queue a new job; does sanity checks and recursively unpacks archives
   until there are no recognized archive types left

- uploadServer: watches for new uploads (via the ProjectSend code hooked on sensorgnome.org/upload;
  unpacks newly-uploaded files recursively, then queues job folder for processing

- processServer: process jobs; there can be multiple instances of processServer
  running.; each watches the master incoming directory
    /sgm/queue/0
  and competes to claim new jobs which are moved there; this happens via atomic
  operations on the 'queue' field of records in the job table.

- statusServer: generates web-page summaries of job processing; currently this
  is called only via the server-side includes on sensorgnome.org pages:

    https://sensorgnome.org/Motus_Processing_Status

  and

    https://sensorgnome.org/My_Job_Status

   which don't permit full navigation, as I haven't found a convenient way to
   do that on the sensorgnome.org dekiwiki

- job folder; A job is a run of a set of files.  e.g. the email server
  generates a job for each valid email, consisting of all attached, downloaded
  and unpacked files from that email, maintaining folder structure so that
  we avoid name collisions

Job information:
   id: unique primary integer;
   pid: parent id; id of job which created this job, if any; a job with pid=null
       is a "top-level" job, created by an external event (receipt of email; upload
       of file, ...)
   stump: id of top-level job; ultimate ancestor of this job
   queue: queue in which this job resides; 'E': email; 'U': upload '1'...'8' process
          server; '0': awaiting a process server;  only valid in top-level jobs

   ctime: numeric; -- creation timestamp
   mtime: numeric; -- modification timestamp
   done: 0: in process; > 0 successful completion; < 0 stopped with error
   type: type of job e.g. 'uploadFile' or 'email'

   data: text; -- json string with additional job details:
       - log: details of what has been done
       - summary: summary for job
       - replyTo: email address for person to notify
       - ... depending on type of job
