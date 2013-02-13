New Elasticsearch Node
========

* Create instance, proper size and security group
* HOST=public ip
* SSH_OPTIONS="-o User=ec2-user -o IdentityFile=./tmp/elasticsearch-prod.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
* sudo yum update
* Booststrap
  scp $SSH_OPTIONS bootstrap.sh patches.sh node.json solo.rb $HOST:/tmp
  time ssh -t $SSH_OPTIONS $HOST "sudo bash /tmp/bootstrap.sh"
  time ssh -t $SSH_OPTIONS $HOST "sudo bash /tmp/patches.sh"
  time ssh -t $SSH_OPTIONS $HOST "sudo chef-solo --node-name elasticsearch-prod-2 -j /tmp/node.json"
* Create synonym files
  ssh -t $SSH_OPTIONS $HOST
  sudo mkdir /etc/elasticsearch && sudo mkdir /etc/elasticsearch/synonyms
  locally: scp $SSH_OPTIONS ../doximity/web/config/synonyms/* $HOST:/tmp
  ssh -t $SSH_OPTIONS $HOST
  sudo mv /tmp/*.txt /etc/elasticsearch/synonyms/
  sudo chown -R elasticsearch:elasticsearch /etc/elasticsearch/
* Edit elasticsearch.yml
  ssh -t $SSH_OPTIONS $HOST
  sudo su -
  sudo su elasticsearch
  vim /usr/local/etc/elasticsearch/elasticsearch.yml
    cluster_name
    node_name
    node_type
    mlockall
    expected_nodes
    unicast
  unicast list to INTERNAL IP:9300
  sudo su -
    ulimit -l unlimited
* ES_MIN_MEM same ES_MAX_MEM (half of total)
  ssh -t $SSH_OPTIONS $HOST "cat /usr/local/etc/elasticsearch/elasticsearch-env.sh"
* sudo service elasticsearch stop
* sudo service elasticsearch start
