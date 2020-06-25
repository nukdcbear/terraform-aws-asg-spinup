#!/bin/bash

echo "${motd}" > /etc/motd

cat > /etc/nginx/conf.d/domo.conf <<EOF
server {
    listen      443 default_server;
    server_name *.davidcbarringer.com;
    root        /var/www/html;
    index       index.html;
}
EOF

# Reset default index.html
cp /var/www/html/index.nginx-debian.html /var/www/html/index.html

# Restart nginx
systemctl restart nginx