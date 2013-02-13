Bootstrap, install and configure ElasticSearch with Chef Solo
=============================================================

The code in this repository bootstraps and configures a fully managed
Elasticsearch installation on a EC2 instance with EBS-based local persistence.

Download or clone the files in this gist:

    curl -# -L -k https://gist.github.com/2050769/download | tar xz --strip 1 -C .

First, in the downloaded `node.json` file, replace the `access_key` and `secret_key`
values with proper AWS credentials.

Second, create a dedicated [security group](https://console.aws.amazon.com/ec2/home?region=us-east-1#s=SecurityGroups)
in the AWS console for ElasticSearch nodes. We will be using group named `elasticsearch-test`.

Make sure the security groups allows connections on following ports:

* Port 22 for SSH is open for external access (the default `0.0.0.0/0`)
* Port 8080 for the Nginx proxy is open for external access (the default `0.0.0.0/0`)
* Port 9300 for in-cluster communication is open to the same security group (use the Group ID for this group,
  available on the "Details" tab, such as `sg-1a23bcd`)

Third, launch a [new instance](https://console.aws.amazon.com/ec2/home?region=us-east-1#s=Instances) in the AWS console:

* Use a meaningful name for the instance. We will use `elasticsearch-test-chef-1`.
* Create a new "Key Pair" for the instance, and download it. We will be using a key named `elasticsearch-test`.
* Use the _Amazon Linux AMI_ ([`ami-1b814f72`](https://aws.amazon.com/amis/amazon-linux-ami-ebs-backed-64-bit)). Amazon Linux comes with Ruby and Java pre-installed.
* Use the `m1.large` instance type. You may use the _small_ or even _micro_ instance type, but the process will take very long, due to AWS constraints (could be hours instead of minutes).
* Use the security group created in the first step (`elasticsearch-test`).

Copy the SSH key downloaded from AWS console to the `tmp/` directory of this project and change its permissions:

    cp ~/Downloads/elasticsearch-test.pem ./tmp
    chmod 600 ./tmp/elasticsearch-test.pem

Once the instance is ready, copy its "Public DNS" in the AWS console
(eg. `ec2-123-40-123-50.compute-1.amazonaws.com`).

We can begin the "bootstrap and install" process now.

Let's setup the connection details, first:

    HOST=<REPLACE WITH YOUR PUBLIC DNS>
    SSH_OPTIONS="-o User=ec2-user -o IdentityFile=./tmp/elasticsearch-test.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

Let's copy the files to the machine:

    scp $SSH_OPTIONS bootstrap.sh patches.sh node.json solo.rb $HOST:/tmp

Let's bootstrap the machine (ie. install neccessary packages, download cookbooks, etc):

    time ssh -t $SSH_OPTIONS $HOST "sudo bash /tmp/bootstrap.sh"
    time ssh -t $SSH_OPTIONS $HOST "sudo bash /tmp/patches.sh"

Let's launch the Chef run with the `chef-solo` command to provision the system:

    time ssh -t $SSH_OPTIONS $HOST "sudo chef-solo -N elasticsearch-test-1 -j /tmp/node.json"

Once the Chef run successfully finishes, you can check whether ElasticSearch is running on the machine
(leave couple of seconds for ElasticSearch to have a chance to start...):

    ssh -t $SSH_OPTIONS $HOST "curl localhost:9200/_cluster/health?pretty"

You can also connect to the Nginx-based proxy:

    curl http://USERNAME:PASSWORD@$HOST:8080

And use it for indexing some data:

    curl -X POST "http://USERNAME:PASSWORD@$HOST:8080/test_chef_cookbook/document/1" -d '{"title" : "Test 1"}'
    curl -X POST "http://USERNAME:PASSWORD@$HOST:8080/test_chef_cookbook/document/2" -d '{"title" : "Test 2"}'
    curl -X POST "http://USERNAME:PASSWORD@$HOST:8080/test_chef_cookbook/document/3" -d '{"title" : "Test 3"}'
    curl -X POST "http://USERNAME:PASSWORD@$HOST:8080/test_chef_cookbook/_refresh"

Or performing searches:

    curl "http://USERNAME:PASSWORD@$HOST:8080/_search?pretty"

You can also use the provided `service` to check ElasticSearch status:

    ssh -t $SSH_OPTIONS $HOST "sudo service elasticsearch status -v"

Of course, you can check the ElasticSearch status with Monit:

    ssh -t $SSH_OPTIONS $HOST "sudo monit reload && sudo monit status -v"

(If the Monit daemon is not running, start it with `sudo service monit start` first. Notice the daemon has a startup delay of 2 minutes by default.)

The provisioning scripts will configure the following on the target instance:

* Install Nginx and Monit
* Install and configure Elasticsearch via the [cookbook](https://github.com/elasticsearch/cookbook-elasticsearch)
* Create, attach, format and mount a new EBS disk
* Configure Nginx as a reverse proxy for Elasticsearch with HTTP authentication
* Configure Monit to check Elasticsearch process status and cluster health

This repository comes with a collection of Rake tasks which automatically create the server in Amazon EC2,
and perform all the provisioning steps. Install the required Rubygems with `bundle install` and run:

    time bundle exec rake create NAME=elasticsearch-test-from-cli

-----

<http://www.elasticsearch.org/tutorials/2012/03/21/deploying-elasticsearch-with-chef-solo.html>
