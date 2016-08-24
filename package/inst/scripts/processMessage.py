#!/usr/bin/python

import argparse
import re
import os
import subprocess
import tempfile
import shutil
import time
import sys
import email

parser = argparse.ArgumentParser()
parser.add_argument("messageFile")
args = parser.parse_args()

mf = args.messageFile

F = open(mf, 'r')

a = F.read()

F.close()

## walk the mime structure
## from :http://stackoverflow.com/questions/17874360/python-how-to-parse-the-body-from-a-raw-email-given-that-raw-email-does-not

b = email.message_from_string(a)
body = ""

if b.is_multipart():
    for part in b.walk():
        ctype = part.get_content_type()
        cdispo = str(part.get('Content-Disposition'))
        # skip any text/plain (txt) attachments
        if ctype == 'text/plain' and 'attachment' not in cdispo:
            body = part.get_payload(decode=True)  # decode
            break
# not multipart - i.e. plain text, no attachments, keeping fingers crossed
else:
    body = b.get_payload(decode=True)

fm = re.search("(https://www.wetransfer.com/downloads/[^\n]*)", body)
if not fm:
    exit
URL = fm.group(1)
td = tempfile.mkdtemp(prefix="/home/sg/tmp")
os.chdir(td)
subprocess.check_output(["/SG/code/getWeTransferFile.R", URL], shell=False).decode("utf-8")
FILE = td + "/" + os.listdir(td)[0]
known = False
suffix = re.search("\\.(zip|rar|7z|7-zip)$", FILE, re.I)
if suffix:
    suffix = suffix.group(1).lower()
else:
    suffix = "none"
    
while not known:
    if suffix == "zip":
        subprocess.call(["/usr/bin/unzip", FILE], shell=False)
        known = True
    elif suffix == "7z" or suffix == "7-zip":
        subprocess.call(["/usr/bin/7z", "x", FILE], shell=False)
        known = True
    elif suffix == "rar":
        subprocess.call(["/usr/bin/unrar", "x", FILE], shell=False)
        known = True
    else:
        ftype = subprocess.check_output(["/usr/bin/file", "-b", FILE], shell=False).decode("utf-8")
        suffix = re.search("(zip|rar|7z|7-zip) archive data", ftype, re.I)
        if suffix:
            suffix = suffix.group(1).lower()
        else:
            break

## NO 2016-08-12:  Pause automatic incoming processing until we've got it working in tandem            
if known:
    if not subprocess.call(["/SG/code/process_incoming_files.R", "."], shell=False) and not subprocess.call(["/SG/code/motusIncomingFiles.R", "."], shell=False):
        os.chdir("..")
        shutil.rmtree(td)
