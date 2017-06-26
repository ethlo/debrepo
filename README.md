# Debrepo shell script
Single-file, minimalist debian repository manager

## Prequisities
A Debian based distro (Tested on Ubuntu).

## Setup web-server
`sudo apt install nginx`

Create vhost `deb.example.com`

# WIP below...

## Install SSL certificate
Instead of using a self-signed SSL certificate, get one from letsencrypt.org

Inside `server` section of `/etc/sites-available/deb.example.com`

```
ssl on;
ssl_certificate /etc/letsencrypt/live/deb.example.com/cert.pem;
ssl_certificate_key /etc/letsencrypt/live/deb.example.com/privkey.pem;
```

## Setup
wget -O https://github.com/ethlo/debrepo/master/debrepo.sh

`/var/www/`
`/home/example/deb-work-dir`

# Install repository public key on clients
wget -O - https://deb.example.com/public.asc --user=username --ask-password | sudo apt-key add -
