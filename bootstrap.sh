echo -e "\nInstalling development dependencies, Ruby and essential tools..." \
        "\n===============================================================================\n"
yum install gcc gcc-c++ make automake install ruby-devel libcurl-devel libxml2-devel libxslt-devel vim curl git -y

echo -e "\nInstalling Rubygems..." \
        "\n===============================================================================\n"
yum install rubygems -y
gem install json --no-ri --no-rdoc

echo -e "\nInstalling and bootstrapping Chef..." \
        "\n===============================================================================\n"
test -d "/opt/chef" || curl -# -L http://www.opscode.com/chef/install.sh | sudo bash -s -- -v 10.18.2

mkdir -p /etc/chef/
mkdir -p /var/chef-solo/site-cookbooks
mkdir -p /var/chef-solo/cookbooks

if test -f /tmp/solo.rb; then mv /tmp/solo.rb /etc/chef/solo.rb; fi

echo -e "\nDownloading cookbooks..." \
        "\n===============================================================================\n"
test -d /var/chef-solo/site-cookbooks/monit || curl -# -L -k http://s3.amazonaws.com/community-files.opscode.com/cookbook_versions/tarballs/915/original/monit.tgz | tar xz -C /var/chef-solo/site-cookbooks/

test  -d /var/chef-solo/site-cookbooks/ark ||  curl -# -L -k http://s3.amazonaws.com/community-files.opscode.com/cookbook_versions/tarballs/1631/original/ark.tgz | tar xz -C /var/chef-solo/site-cookbooks

if [ ! -d /var/chef-solo/cookbooks/elasticsearch ]; then
  git clone git://github.com/brupm/cookbook-elasticsearch.git /var/chef-solo/cookbooks/elasticsearch
else
  cd /var/chef-solo/cookbooks/elasticsearch
  git fetch
  git reset origin/master --hard
fi

echo -e "\n*******************************************************************************\n" \
        "Bootstrap finished" \
        "\n*******************************************************************************\n"
