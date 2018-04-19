#!/bin/bash
# -------
# This is common script which will be called to generate SSL
# -------

# Configure constants
if [ -f "constants.sh" ]; then
  . constants.sh
fi

# Configure colors
if [ -f "colors.sh" ]; then
  . colors.sh
fi

local_domain=$1
#local_port=$2
echo "SSL for domain : $local_domain is being created...."
if [ ! -f "/etc/letsencrypt/live/$local_domain/fullchain.pem" ]; then
  sudo certbot certonly --authenticator standalone --installer nginx -d $local_domain --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"
fi

if [ -f "/etc/letsencrypt/live/$local_domain/fullchain.pem" ]; then

  sudo rsync -avz $NGINX_CONF/sites-available/domain.conf.ssl /etc/nginx/sites-available/$local_domain.conf
  sudo ln -s /etc/nginx/sites-available/$local_domain.conf /etc/nginx/sites-enabled/
    
  sudo sed -i "s/@@DNS_DOMAIN@@/$local_domain/g" /etc/nginx/sites-available/$local_domain.conf

  #sudo sed -i "s/@@PORT@@/$local_port/g" /etc/nginx/sites-available/$local_domain.conf

  echo "SSL for domain : $local_domain has been created successfully."

else
  echored "There is an error in generating keys for domain $local_domain."
fi


sudo systemctl restart nginx
echogreen "Finished installing SSL"

# Add cron job to renew key
crontab -l | { cat; echo '43 6 * * * root /usr/bin/certbot renew --post-hook "systemctl reload nginx" > /var/log/certbot-renew.log'; } | crontab -
