#!/bin/bash
# -------
# This is script which defines constants
# -------

export DEVOPS_HOME=/home/devops
export CATALINA_HOME=$DEVOPS_HOME/tomcat
export BASE_INSTALL=/home/ubuntu/devops
export TMP_INSTALL=/tmp/devops-install
export NGINX_CONF=$BASE_INSTALL/_ubuntu/etc/nginx
export LOCALESUPPORT=en_US.utf8
export GLOBAL_PROTOCOL=https
export DEVOPS_USER=devops
export DEVOPS_GROUP=$DEVOPS_USER
export DEFAULTDB=MA

export APTVERBOSITY="-qq -y"
export DEFAULTYESNO="y"

export TIME_ZONE="Asia/Ho_Chi_Minh"
export LC_ALL="C"

export NODEJSURL=https://deb.nodesource.com/setup_8.x

