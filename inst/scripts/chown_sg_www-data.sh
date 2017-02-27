#!/bin/bash
# change owner:group of uploaded file to sg:www-data
# (it is originally uploaded as www-data:www-data)

chown sg:www-data "$1"
