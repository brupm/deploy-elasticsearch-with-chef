# Patch Monit cookbook problems
mkdir -p /etc/monit/conf.d/
rm -f /etc/monit.conf
touch /etc/monit/monitrc
chmod 700 /etc/monit/monitrc
ln -nfs /etc/monit/monitrc /etc/monit.conf

# Patch Nginx cookbook problems
mkdir -p /etc/nginx/sites-available/
useradd -s /bin/sh -u 33 -U -d /var/www -c Webserver www-data

echo -e "\n*******************************************************************************\n" \
        "Patching finished" \
        "\n*******************************************************************************\n"