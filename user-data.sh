#!/bin/bash
# user-data.sh — bootstraps each EC2 instance in the ASG
# Rendered via templatefile() in main.tf using path.module
# Variables injected: server_port, app_name

set -euo pipefail

# Update packages and install a minimal HTTP server
yum update -y
yum install -y httpd

# Write a simple index page identifying this node
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
  <head><title>${app_name}</title></head>
  <body>
    <h1>Hello, Welcome back Wadondera! ${app_name}</h1>
    <p>Served from: $(hostname -f)</p>
  </body>
</html>
EOF

# Configure Apache to listen on the custom port
sed -i "s/^Listen 80/Listen ${server_port}/" /etc/httpd/conf/httpd.conf

# Enable and start Apache
systemctl enable httpd
systemctl start httpd
