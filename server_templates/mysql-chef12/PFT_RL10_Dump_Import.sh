#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: PFT RL10 Dump Import
# Description: Imports the database schema for the sample application
# Inputs:
#   SERVER_ROOT_PASSWORD:
#     Category: Database
#     Description: 'The root password for MySQL server. Example: cred:MYSQL_ROOT_PASSWORD'
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

set -e

cd /tmp

curl https://raw.githubusercontent.com/rightscale/examples/unified_php/app_test.sql -O

mysql -p$SERVER_ROOT_PASSWORD < app_test.sql
