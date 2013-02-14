sudo rpm -Uvh http://download.newrelic.com/pub/newrelic/el5/i386/newrelic-repo-5-3.noarch.rpm
sudo yum install newrelic-sysmond
sudo nrsysmond-config --set license_key=292071c5d709b0d8acbff6bac9c5623579043186
sudo /etc/init.d/newrelic-sysmond start
