#! /bin/bash

:<<EOF
1 change password: gitlab_user_password
2 chage domain: git.ooooooo.me
EOF

# run as root!
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install sudo -y

# Install vim and set as default editor
sudo apt-get install -y vim
sudo update-alternatives --set editor /usr/bin/vim.basic

# install mysql
sudo apt-get install mysql-server mysql-client libmysqlclient-dev

sudo apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev

sudo grep 'deb http://backports.debian.org/debian-backports squeeze-backports main' /etc/apt/sources.list || sudo sh -c 'echo "deb http://backports.debian.org/debian-backports squeeze-backports main" >> /etc/apt/sources.list'
sudo apt-get update -y
sudo apt-get install -y -t squeeze-backports redis-server
sudo apt-get install -y -t squeeze-backports git

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
	curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
	cd ruby-2.0.0-p247
	./configure
	make
	sudo make install
fi

sudo gem install bundler --no-ri --no-rdoc

sudo adduser --disabled-login --gecos 'GitLab' git


# Go to home directory
cd /home/git

# Clone gitlab shell
test -d gitlab-shell && sudo rm -rf gitlab-shell
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git

cd gitlab-shell

# switch to right version
sudo -u git -H git checkout v1.4.0

sudo -u git -H cp config.yml.example config.yml

# Edit config and replace gitlab_url
# with something like 'http://domain.com/'
##sudo -u git -H editor config.yml
sudo -u git -H sed -i 's#gitlab_url: "http://localhost/"#gitlab_url: "http://git.ooooooo.me/"#' config.yml

# Do setup
sudo -u git -H ./bin/install

# setup database
root_pswd=root_user_password
gitlab_pswd=gitlab
mysql -uroot -p$root_pswd -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$gitlab_pswd';";
mysql -uroot -p$root_pswd -e "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;";
mysql -uroot -p$root_pswd -e "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO 'gitlab'@'localhost';";

# We'll install GitLab into home directory of the user "git"
cd /home/git

# Clone GitLab repository
test -d gitlab && sudo rm -rf gitlab
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab

# Go to gitlab dir
cd /home/git/gitlab

# Checkout to stable release
sudo -u git -H git checkout 5-3-stable


cd /home/git/gitlab

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

# Make sure to change "localhost" to the fully-qualified domain name of your
# host serving GitLab where necessary
##sudo -u git -H editor config/gitlab.yml
sudo -u git -H sed -i 's#    host: localhost#    host: git.ooooooo.me#' config/gitlab.yml
#sudo -u git -H sed -i 's#    port: 80#    port: 8008#' config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX  log/
sudo chmod -R u+rwX  tmp/

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites

# Create directories for sockets/pids and make sure GitLab can write to them
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
sudo chmod -R u+rwX  tmp/pids/
sudo chmod -R u+rwX  tmp/sockets/

# Create public/uploads directory otherwise backup will fail
sudo -u git -H mkdir public/uploads
sudo chmod -R u+rwX  public/uploads

# Copy the example Puma config
sudo -u git -H cp config/puma.rb.example config/puma.rb
##sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

# Enable cluster mode if you expect to have a high load instance
# Ex. change amount of workers to 3 for 2GB RAM server
##sudo -u git -H vim config/unicorn.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@localhost"


# Configure GitLab DB settings
# Mysql
sudo -u git cp config/database.yml.mysql config/database.yml

##sudo -u git -H editor config/database.yml
sudo -u git -H sed -i 's#  username: root#  username: gitlab#' config/database.yml
sudo -u git -H sed -i 's#  password: "secure password"#  password: "gitlab_user_password"#' config/database.yml

# Make config/database.yml readable to git only
sudo -u git -H chmod o-rwx config/database.yml

cd /home/git/gitlab

sudo gem install charlock_holmes --version '0.6.9.4'

# For MySQL (note, the option says "without ... postgres")
sudo -u git -H bundle install --deployment --without development test postgres unicorn aws

sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production
# Type 'yes' to create the database.
# When done you see 'Administrator account created:'

sudo cp lib/support/init.d/gitlab /etc/init.d/gitlab
sudo chmod a+x /etc/init.d/gitlab
sudo update-rc.d gitlab defaults 21

sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

sudo cp lib/support/nginx/gitlab /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo rm -f /usr/local/webserver/nginx/conf/sites-enabled/gitlab
sudo ln -s /usr/local/webserver/nginx/conf/sites-available/gitlab /usr/local/webserver/nginx/conf/sites-enabled/gitlab

# Change YOUR_SERVER_FQDN to the fully-qualified
# domain name of your host serving GitLab.
##sudo editor /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i 's#listen YOUR_SERVER_IP:80 #listen *:80 #' /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i 's#YOUR_SERVER_FQDN#git.ooooooo.me#' /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i 's#listen \*:80 default_server;#listen *:80;#' /usr/local/webserver/nginx/conf/sites-available/gitlab
sudo sed -i 's#/var/log/nginx/#/usr/local/webserver/nginx/logs/#' /usr/local/webserver/nginx/conf/sites-available/gitlab


sudo /usr/local/webserver/nginx/sbin/nginx -s reload

