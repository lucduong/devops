#!/bin/bash
# -------
# Script to configure and setup Nginx, PM2, Nodejs, Redis, MongoDB, CertbotSSL, SSL
#
# -------

# Configure constants
if [ -f "constants.sh" ]; then
  . constants.sh
fi

# Configure colors
if [ -f "colors.sh" ]; then
  . colors.sh
fi

echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echogreen "Begin running...."
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo


URLERROR=0

for REMOTE in $NODEJSURL
do
        wget --spider $REMOTE --no-check-certificate >& /dev/null
        if [ $? != 0 ]
        then
                echored "Please fix this URL: $REMOTE and try again later"
                URLERROR=1
        fi
done

if [ $URLERROR = 1 ]
then
    echo
    echored "Please fix the above errors and rerun."
    echo
    exit
fi

# Create temporary folder for storing downloaded files
if [ ! -d "$TMP_INSTALL" ]; then
  mkdir -p $TMP_INSTALL
fi


##
# Nginx
##
echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Nginx can be used as frontend to NodeJS."
echo "This installation will add config default proxying to NodeJS running behind."
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
read -e -p "Install nginx${ques} [y/n] " -i "$DEFAULTYESNO" installnginx
if [ "$installnginx" = "y" ]; then

  # Remove nginx if already installed
  if [ "`which nginx`" != "" ]; then
   sudo apt-get remove --auto-remove nginx nginx-common
   sudo apt-get purge --auto-remove nginx nginx-common
  fi
  echoblue "Installing nginx. Fetching packages..."
  echo

  sudo apt-get $APTVERBOSITY update
  sudo apt-get $APTVERBOSITY install nginx
  # Enable Nginx to auto start when Ubuntu is booted
  sudo systemctl enable nginx
  # Check Nginx status
  #systemctl status nginx
  
  #TODO: sudo service nginx stop
  #sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
  #sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.sample
  
  # Insert config for letsencrypt
  if [ ! -d "/opt/letsencrypt/.well-known" ]; then
  sudo mkdir -p /opt/letsencrypt/.well-known
  echo "Hello HTTP!" | sudo tee /opt/letsencrypt/index.html
  fi
  
  sudo chown -R www-data:root /opt/letsencrypt
  
  if [ ! -f "/etc/nginx/conf.d/default.conf" ]; then
  sudo rsync -avz $NGINX_CONF/conf.d/default.conf /etc/nginx/conf.d/    
  else
  sed -i '/^\(}\)/ i location \/\.well-known {\n  alias \/opt\/letsencrypt\/\.well-known\/;\n  allow all;  \n  }' /etc/nginx/conf.d/default.conf
  fi
  
  if [ -f "/etc/nginx/sites-available/default" ]; then
  sed -i '/^\(}\)/ i location \/\.well-known {\n  alias \/opt\/letsencrypt\/\.well-known\/;\n  allow all;  \n  }' /etc/nginx/sites-available/default
  fi
  
  if [ ! -f "/etc/nginx/snippets/ssl.conf" ]; then
  sudo cat <<EOF >/etc/nginx/snippets/ssl.conf
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

ssl_protocols TLSv1.2;
ssl_ciphers EECDH+AESGCM:EECDH+AES;
ssl_ecdh_curve secp384r1;
ssl_prefer_server_ciphers on;

ssl_stapling on;
ssl_stapling_verify on;

add_header Strict-Transport-Security "max-age=15768000; includeSubdomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
EOF
  fi
  
  ## Reload config file
  #TODO: sudo service nginx start
  sudo systemctl restart nginx
  
  sudo ufw enable
  if [ ! -f "/etc/ufw/applications.d/nginx.ufw.profile" ]; then
  echo "There is no profile for nginx within ufw, so we decide to create it."
  sudo cat <<EOF >/etc/ufw/applications.d/nginx.ufw.profile
[Nginx HTTP]
title=Web Server (Nginx, HTTP)
description=Small, but very powerful and efficient web server
ports=80/tcp

[Nginx HTTPS]
title=Web Server (Nginx, HTTPS)
description=Small, but very powerful and efficient web server
ports=443/tcp

[Nginx Full]
title=Web Server (Nginx, HTTP + HTTPS)
description=Small, but very powerful and efficient web server
ports=80,443/tcp
EOF

  sudo ufw app update nginx
  fi

  sudo ufw allow 'Nginx HTTP'
  sudo ufw allow 'Nginx HTTPS'
  sudo ufw allow 'OpenSSH'


  echo
  echogreen "Finished installing nginx"
  echo
else
  echo "Skipping install of nginx"
fi

##
# Node JS
##
echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Begin setting up a nodejs..."
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
read -e -p "Install nodejs${ques} [y/n] " -i "$DEFAULTYESNO" installnodejs
if [ "$installnodejs" = "y" ]; then
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "Installing & Configuring NodeJS LTS (v8)"
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  curl -sL $NODEJSURL | sudo -E bash -
  sudo apt-get $APTVERBOSITY install nodejs
  sudo npm install -g npm@latest
  
  # [Optional] Some NPM packages will probably throw errors when compiling
  sudo apt-get $APTVERBOSITY install build-essential
fi

##
# PM2
##
echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Begin setting up a PM2..."
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
read -e -p "Install PM2${ques} [y/n] " -i "$DEFAULTYESNO" installpm2
if [ "$installpm2" = "y" ]; then
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "You need to install PM2"
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  sudo npm install -g pm2
  
    # Launch PM2 and its managed processes on server boots
    pm2 startup systemd
    sudo chown $USER:$USER ~/.pm2/rpc.sock ~/.pm2/pub.sock
    pm2 list
fi

##
# Redis
##
echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Begin setting up a Redis..."
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
read -e -p "Install Redis${ques} [y/n] " -i "$DEFAULTYESNO" installredis
if [ "$installredis" = "y" ]; then
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "You need to install Redis"
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  sudo apt-get $APTVERBOSITY install redis-server
  # sudo chmod 770 /etc/redis/redis.conf
  echo "maxmemory 1024mb" | sudo tee --append /etc/redis/redis.conf
    echo "maxmemory-policy allkeys-lru" | sudo tee --append /etc/redis/redis.conf
  sudo systemctl enable redis-server.service
fi

##
# MongoDB
##
echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Begin setting up a MongoDB..."
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
read -e -p "Install MongoDB${ques} [y/n] " -i "$DEFAULTYESNO" installmongodb
if [ "$installmongodb" = "y" ]; then
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  echo "You need to install MongoDB"
  echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  
  # Import the key for the official MongoDB repository
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
  
    # Create a list file for MongoDB
    echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  
    sudo apt-get $APTVERBOSITY update
  
    # Install mongodb-org, which includes the daemon, configuration and init scripts, shell, and management tools on the server. 
    sudo apt-get $APTVERBOSITY install -y mongodb-org
  
    # Ensure that MongoDB restarts automatically at boot
    sudo systemctl enable mongod   
    sudo systemctl start mongod
fi

##
# Certbot SSL
##
echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Certbot SSL"
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
read -e -p "Install certbot${ques} [y/n] " -i "$DEFAULTYESNO" installcertbot
if [ "$installcertbot" = "y" ]; then

  # Remove nginx if already installed
  if [ "`which certbot`" != "" ]; then
    # Uninstall Certbot
    sudo apt-get purge python-certbot-nginx
    sudo rm -rf /etc/letsencrypt
  fi
  echoblue "Installing Certbot. Fetching packages..."
  echo  
  sudo add-apt-repository ppa:certbot/certbot
  sudo apt-get $APTVERBOSITY update
  sudo apt-get $APTVERBOSITY install -y python-certbot-nginx
  echo
  echogreen "Finished installing Certbot"
  echo
else
  echo "Skipping install of Certbot"
fi


##
# SSL
##
echo
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Begin setting up a SSL..."
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echoblue "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
read -e -p "Install ssl${ques} [y/n] " -i "$DEFAULTYESNO" installssl
if [ "$installssl" = "y" ]; then
  local_port=443
  read -e -p "Please enter the public host name for your server (fully qualified domain name)${ques} [`hostname`] " -i "`hostname`" hostname
  
  if [ -f "$BASE_INSTALL/ssl.sh" ]; then
    . $BASE_INSTALL/ssl.sh $hostname
  else
    . ssl.sh $hostname
  fi
  sudo mkdir temp
  sudo cp $NGINX_CONF/sites-available/common.snippet  temp/
  sudo sed -e '/##COMMON##/ {' -e 'r temp/common.snippet' -e 'd' -e '}' -i /etc/nginx/sites-available/$hostname.conf
  sudo sed -i "s/@@PORT@@/8080/g" /etc/nginx/sites-available/$local_domain.conf
  sudo rm -rf temp
fi
