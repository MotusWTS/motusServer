Sketch of motus server modules

Principles:

   - atomic completion of jobs and jobSteps

   - on interrupt / resume, must be able to resume uncompleted jobs
     and jobSteps

   - full details on what has been done and its status

   - easy to read for web server

Storing state:

   - pure filesystem (e.g. filenames that encode steps, parameters; existing version)
      - pro: persistent, easy to script, atomic,
      - con: have to encode parameters; filenames get long; have to avoid collisions (use timestamps in filenames)

   - .sqlite database in each job directory
      - pro: persistent, atomic, no worries about encoding etc.
      - con: slightly harder to script

   - master database in /sgm/server.sqlite
      - pro: everything in one place for queries etc.; atomic
      - con: any?

- incoming emails processed by /sgm/bin/incomingEmail.sh
  - message -> drop carriage returns -> /sgm/inbox/TS

- emailServer: job is to watch for new messages (via close_write) in /sgm/inbox, then
   create and queue a new job; does not unpack archives, but does sanity checks
   on downloaded files

- jobServer: process jobs; there can be multiple instances of mainServer
  running.; each watches its own incoming directory
  /sgm/queueN

- allocServer: watch for jobs added to /sgm/incoming; choose a running server
  N and move the job to /sgm/queueN
  
- job folder; A job is a run of a set of files.  e.g. the email server
  generates a job for each valid email, consisting of all attached, downloaded
  and unpacked files from that email, maintaining folder structure so that
  we avoid name collisions

Job information:
   id: unique primary integer;
   ts: numeric; -- starting timestamp
   tsEnd: numeric; -- ending timestamp (ending timestamp of last task)
   complete: boolean; (true if all tasks are complete)
   info: text; -- json string with job info
       - type of job (name of handler)
       - owner: email address for person to notify
       - params (named object)

Step information:
   id: unique primary big integer;
   ts: numeric; -- starting timestamp
   tsLast: numeric; -- last activity timestamp
   jobID: ID of parent job;
   complete: boolean;
   info: text; json string with task info
      - type of step (name of handler)
      - params (named object)
   errors: text; json string with error info
      [
       {
        retCode: integer;
        msg: string;
        }...
      ]

Job type "email"
- parameters:
   - msgfile: name of message file (without bz2 extension); e.g. YYYY-MM-DDTHH-MM-SS.NNNNNNNNN
   - headers: array of name:value pairs for retained headers (Reply-To, From, Subject)
   - text: message text

Job steps for job "email"
  - one step for each attached file, to run sanity check

  - two steps for each unique download URL; one to download; one to sanity check

  - one step to send summary email to sender

- dir structure under (e.g.) /sgm/queue/0/00000123
    - YYYY-MM-DDTHH-MM-SS.NNNNNNNNN(.bz2) - message file; compressed after being unpacked
    - msg symlink to above e.g -> YYYY-MM-DDTHH-MM-SS.NNNNNNNNN.bz2
    - attachments:
    - downloads: folder
      - downloads/1: folder with files from 1st download link
      ...
      - downloads/n: folder with files from nth download link

jobStep: name="checkFile"
 parameters:
  path: path to file relative to job directory

jobStep: name="download"
 parameters:
  URL: full URL
  type: "googleDrive", "dropbox", "wetransferDirect", "wetransferConf", "FTP"
 

 

    
    
    /msgparts: folder
  




