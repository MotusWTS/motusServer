Draft instructions - not finalized 

If a new Lotek codeset is added, several steps are needed. These notes were created when Lotek6M was added in Sept. 2020.
Lotek6M has the same base set of codes than Lotek4. All tags in Lotek4 should be identical to the equivalent ID in Lotek6M, 
but Lotek6M adds about 220 new codes.

Lotek sqlite files should not remain available on the server in unencrypted format.

First, open one of the existing sqlite file and insert or replace the code set values. Name the file to match the codeset 
name (e.g. Lotek6M.sqlite). Ensure that the file is owned by user sg.

Second, encrypt the file using gpg. To encrypt the file (make sure this is done as user sg, and that the sqlite file is also owned by sg):

  sudo su - sg
  tmux
  gpg -o Lotek6M.sqlite.gpg -c Lotek6M.sqlite
  <enter passphrase>
  mv Lotek6M.sqlite.gpg /home/sg/lotekdb/
  
Note: check if file permissions are correct on the gpg file (-rw-r--r--  instead of -rw-r-x--- )

If you need to decrypt one of the files:

  gpg -d --passphrase-fd 0 --batch Lotek6M.sqlite.gpg > Lotek6M.sqlite
  <enter passphrase>

Third, use git grep to locate all instances of the codeset names in the existing motusServer R files. Make the necessary modifications 
to the code and republish the R package (need to link to instructions)

  git grep "Lotek[3|4|6M]"
  
