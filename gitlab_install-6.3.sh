#! /bin/bash

:<<EOF
by Zandy
EOF

# config
db_root_pswd=1234567
db_gitlab_pswd=1234567
mygitlab_domain=git.example.com


# run as root!
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install sudo -y

# Install vim and set as default editor
sudo apt-get install -y vim
sudo update-alternatives --set editor /usr/bin/vim.basic

# install mysql
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev

sudo apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate

redis_version=$(redis-cli --version 2>&1|awk '{print $2}')
mairedis=$(echo ${redis_version:-0}|awk '{if ($0 >= "2.0.0"){print 1}else{print 0}}')
if [ $mairedis -eq 0 ]; then
	echo "redis version must be more than 2.0.0, current is $redis_version"
	exit 1
fi

#sudo grep 'deb http://backports.debian.org/debian-backports squeeze-backports main' /etc/apt/sources.list || sudo sh -c 'echo "deb http://backports.debian.org/debian-backports squeeze-backports main" >> /etc/apt/sources.list'
#sudo apt-get update -y
#sudo apt-get install -y -t squeeze-backports redis-server
#sudo apt-get install -y -t squeeze-backports git

# Make sure you have the right version of Python installed.
# Install Python
sudo apt-get install -y python

# Make sure that Python is 2.5+ (3.x is not supported at the moment)
python_version=$(python --version 2>&1|awk '{print $2}')
maipython=$(echo ${python_version:-0}|awk '{if ($0 >= 2.6){print 1}else{print 0}}')

# If it's Python 3 you might need to install Python 2 separately
if [ $maipython -eq 0 ]; then
	sudo apt-get install python2.7
fi

# Make sure you can access Python via python2
##python2 --version

# If you get a "command not found" error create a link to the python binary
if [ ! -f /usr/bin/python2 ]; then
	sudo ln -s /usr/bin/python /usr/bin/python2
fi

sudo apt-get install -y postfix

#sudo apt-get remove -y ruby1.8

ruby_version=$(ruby -v|awk '{print $2}')
mairuby=$(echo ${ruby_version:-0}|awk '{if ($0 >= 1.9.3){print 1}else{print 0}}')
if [ $mairuby -eq 0 ]; then
	mkdir /tmp/ruby && cd /tmp/ruby
	curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz | tar xz
	cd ruby-2.0.0-p353
	./configure --disable-install-rdoc
	make
	sudo make install
fi

# Install the Bundler Gem:
sudo gem install bundler --no-ri --no-rdoc
# Create a git user for Gitlab:
sudo adduser --disabled-login --gecos 'GitLab' git

# Go to home directory
cd /home/git

# Clone gitlab shell
test -d gitlab-shell && sudo rm -rf gitlab-shell
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git

cd gitlab-shell

# switch to right version
sudo -u git -H git checkout v1.7.9
sudo -u git -H sed -i "s~^source \"http[s]*://rubygems.org\"~#source \"https://rubygems.org\"\nsource \"http://ruby.taobao.org/\"~" Gemfile

sudo -u git -H cp config.yml.example config.yml

# Edit config and replace gitlab_url
# with something like 'http://domain.com/'
##sudo -u git -H editor config.yml
sudo -u git -H sed -i "s#gitlab_url: \"http://localhost/\"#gitlab_url: \"http://$mygitlab_domain/\"#" config.yml

# Do setup
sudo -u git -H ./bin/install

# setup database
mysql -uroot -p$db_root_pswd -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$db_gitlab_pswd';";
mysql -uroot -p$db_root_pswd -e "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;";
mysql -uroot -p$db_root_pswd -e "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO 'gitlab'@'localhost';";

# We'll install GitLab into home directory of the user "git"
cd /home/git

# Clone GitLab repository
test -d gitlab && sudo rm -rf gitlab
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab

# Go to gitlab dir
cd /home/git/gitlab

# Checkout to stable release
sudo -u git -H git checkout 6-3-stable
sudo -u git -H sed -i "s~^source \"http[s]*://rubygems.org\"~#source \"https://rubygems.org\"\nsource \"http://ruby.taobao.org/\"~" Gemfile

cd /home/git/gitlab

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

# Make sure to change "localhost" to the fully-qualified domain name of your
# host serving GitLab where necessary
#
# If you installed Git from source, change the git bin_path to /usr/local/bin/git
##sudo -u git -H editor config/gitlab.yml
sudo -u git -H sed -i "s#    host: localhost#    host: $mygitlab_domain#" config/gitlab.yml
#sudo -u git -H sed -i "s#    port: 80#    port: 8008#" config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX  log/
sudo chmod -R u+rwX  tmp/

# Create directory for satellites
sudo -u git -H mkdir -p /home/git/gitlab-satellites
if [ -d /home/git/gitlab-satellites ]; then
	sudo ls /home/git/gitlab-satellites|xargs -I {} sudo rm -rf /home/git/gitlab-satellites/{}
fi
# Clear directory for repositories
if [ -d /home/git/repositories ]; then
	sudo ls /home/git/repositories|xargs -I {} sudo rm -rf /home/git/repositories/{}
fi

# Create directories for sockets/pids and make sure GitLab can write to them
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
sudo chmod -R u+rwX  tmp/pids/
sudo chmod -R u+rwX  tmp/sockets/

# Create public/uploads directory otherwise backup will fail
sudo -u git -H mkdir public/uploads
sudo chmod -R u+rwX  public/uploads

# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

# Enable cluster mode if you expect to have a high load instance
# Ex. change amount of workers to 3 for 2GB RAM server
##sudo -u git -H vim config/unicorn.rb

# Copy the example Rack attack config
sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@localhost"
sudo -u git -H git config --global core.autocrlf input

# Configure GitLab DB settings
# Mysql
sudo -u git cp config/database.yml.mysql config/database.yml

##sudo -u git -H editor config/database.yml
sudo -u git -H sed -i "s#  username: root#  username: gitlab#" config/database.yml
sudo -u git -H sed -i "s#  password: \"secure password\"#  password: \"$db_gitlab_pswd\"#" config/database.yml

# Make config/database.yml readable to git only
sudo -u git -H chmod o-rwx config/database.yml

cd /home/git/gitlab

# For MySQL (note, the option says "without ... postgres")
sudo -u git -H bundle install --deployment --without development test postgres aws

# Initialize Database
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production
# Type 'yes' to create the database.
# When done you see 'Administrator account created:'

# Install Init Script
# Download the init script (will be /etc/init.d/gitlab):
sudo cp lib/support/init.d/gitlab /etc/init.d/gitlab
sudo chmod +x /etc/init.d/gitlab
# Make GitLab start on boot:
sudo update-rc.d gitlab defaults 21

# Set up logrotate
sudo cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

# Check Application Status
# Check if GitLab and its environment are configured correctly:
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
# Start or Restart Your GitLab Instance
sudo /etc/init.d/gitlab restart
# Double-check Application Status
# To make sure you didn't miss anything run a more thorough check with:
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
# If all items are green, then congratulations on successfully installing GitLab! However there are still a few steps left.

# Installation
#sudo apt-get install -y nginx
# Site Configuration
# Download an example site config:
#sudo cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
#sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
# Change YOUR_SERVER_FQDN to the fully-qualified
# domain name of your host serving GitLab.
#sudo editor /etc/nginx/sites-available/gitlab
#sudo service nginx restart

sudo cp lib/support/nginx/gitlab /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo rm -f /usr/local/webserver/nginx/conf/sites-enabled/gitlab
sudo ln -s /usr/local/webserver/nginx/conf/sites-available/gitlab /usr/local/webserver/nginx/conf/sites-enabled/gitlab

# Change YOUR_SERVER_FQDN to the fully-qualified
# domain name of your host serving GitLab.
##sudo editor /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i "s#listen YOUR_SERVER_IP:80 #listen *:80 #" /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i "s#YOUR_SERVER_FQDN#$mygitlab_domain#" /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i "s#listen \*:80 default_server;#listen *:80;#" /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i "s#/var/log/nginx/#/usr/local/webserver/nginx/logs/#" /usr/local/webserver/nginx/conf/sites-available/gitlab


sudo /usr/local/webserver/nginx/sbin/nginx -s stop
sleep 1
sudo /usr/local/webserver/nginx/sbin/nginx