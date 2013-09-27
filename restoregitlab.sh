#! /bin/bash

cd /home/git/gitlab
bundle exec rake gitlab:backup:restore RAILS_ENV=production
#bundle exec rake gitlab:backup:restore RAILS_ENV=production BACKUP=$timestamp_of_backup

