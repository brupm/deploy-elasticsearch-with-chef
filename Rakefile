require 'rubygems'
require 'json'
require 'fog'
require 'ansi'

module Provision

  class Server
    attr_reader :name, :options, :node, :ui

    def initialize(options = {})
      @options   = options
      @name      = @options.delete(:name)
    end

    def create!
      create_node
      tag_node
      msg "Waiting for SSH...", :yellow
      wait_for_sshd and puts
    end

    def destroy!
      servers = connection.servers.select { |s| s.tags["Name"] =~ Regexp.new(name) && s.state != 'terminated' }
      if servers.empty?
        msg "[!] No instance named '#{name}' found!", :red
        exit(1)
      end

      servers.each do |s|
        @node = s
        msg "Found EC2 instance #{node.tags["Name"]} (#{node.id}), terminating...", :yellow
        connection.terminate_instances(node.id)
        msg "EC2 instance was terminated.", :green
      end
    end

    def connection
      @connection ||= Fog::Compute.new(
          :provider              => 'AWS',
          :aws_access_key_id     => options[:aws_access_key_id],
          :aws_secret_access_key => options[:aws_secret_access_key],
          :region                => options[:aws_region]
      )
    end

    def node
      @node ||= connection.servers.select do |s|
                  s.tags["Name"] =~ Regexp.new(name) && s.state != 'terminated'
                end.first
    end

    def create_node
      msg "Creating EC2 instance #{name} in #{options[:aws_region]}...", :bold
      msg "-"*ANSI::Terminal.terminal_width

      @node = connection.servers.create(:image_id   => options[:aws_image],
                                        :groups     => options[:aws_groups].split(",").map {|x| x.strip},
                                        :flavor_id  => options[:aws_flavor],
                                        :key_name   => options[:aws_ssh_key_id],
                                        :block_device_mapping => options[:block_device_mapping] || [ { "DeviceName" => "/dev/sde1", "VirtualName" => "ephemeral0" }]
      )

      msg_pair "Instance ID",       node.id
      msg_pair "Flavor",            node.flavor_id
      msg_pair "Image",             node.image_id
      msg_pair "Region",            options[:aws_region]
      msg_pair "Availability Zone", node.availability_zone
      msg_pair "Security Groups",   node.groups.join(", ")
      msg_pair "SSH Key",           node.key_name

      msg "Waiting for instance...", :yellow
      @node.wait_for { print "."; ready? }
      puts

      msg_pair "Public DNS Name",    node.dns_name
      msg_pair "Public IP Address",  node.public_ip_address
      msg_pair "Private DNS Name",   node.private_dns_name
      msg_pair "Private IP Address", node.private_ip_address
    end

    def tag_node
      msg "Tagging instance in EC2...", :yellow

      custom_tags  = options[:tags].split(",").map {|x| x.strip} rescue []

      tags         = Hash[*custom_tags]
      tags["Name"] = @name

      tags.each_pair do |key, value|
        connection.tags.create :key => key, :value => value, :resource_id => @node.id
        msg_pair key, value
      end
    end

    def wait_for_sshd
      hostname = node.dns_name
      loop do
        begin
          print(".")
          tcp_socket = TCPSocket.new(hostname, 22)
          readable = IO.select([tcp_socket], nil, nil, 5)
          if readable
            msg "SSHd accepting connections on #{hostname}, banner is: #{tcp_socket.gets}", :green
            return true
          end
        rescue SocketError
          sleep 2
          retry
        rescue Errno::ETIMEDOUT
          sleep 2
          retry
        rescue Errno::EPERM
          return false
        rescue Errno::ECONNREFUSED
          sleep 2
          retry
        rescue Errno::EHOSTUNREACH
          sleep 2
          retry
        ensure
          tcp_socket && tcp_socket.close
        end
      end
    end

    def ssh(command)
      host = node.dns_name
      user = options[:ssh_user]
      key  = options[:ssh_key]
      opts = "-o User=#{user} -o IdentityFile=#{key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

      system "ssh -t #{opts} #{host} #{command}"
    end

    def scp(files, params={})
      host = node.dns_name
      user = options[:ssh_user]
      key  = options[:ssh_key]
      opts = "-o User=#{user} -o IdentityFile=#{key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
      path = params[:path] || '/tmp'

      __command = "scp #{opts} #{files} #{host}:#{path}"
      puts   __command
      system __command
    end

    def msg message, color=:white
      puts message.ansi(color)
    end

    def msg_pair label, value, color=:cyan
      puts (label.to_s.ljust(25) + value.to_s).ansi(color)
    end

  end

end

desc "Create, bootstrap and configure an instance in EC2"
task :create => :setup do
  @server = Provision::Server.new @args

  @server.create!

  Rake::Task[:upload].execute
  Rake::Task[:provision].execute
end

desc "Terminate an EC2 instance"
task :destroy => :setup do
  @server = Provision::Server.new @args
  @server.destroy!
end

desc "(Re-)provision an instance"
task :provision => :setup do
  @server ||= Provision::Server.new @args

  @server.ssh "sudo bash /tmp/bootstrap.sh"
  @server.ssh "sudo bash /tmp/patches.sh"
  @server.ssh "sudo chef-solo -N #{@server.name} -j /tmp/#{@args[:node_json]}"

  exit(1) unless $?.success?

  puts "_"*ANSI::Terminal.terminal_width
  puts "\nOpen " + "http://#{@args[:http_username]}:#{@args[:http_password]}@#{@server.node.dns_name}:8080".ansi(:bold) + " in your browser"
end

task :upload => :setup do
  @server ||= Provision::Server.new @args
  @server.scp "bootstrap.sh patches.sh #{@args[:node_json]} solo.rb", :path => '/tmp'
  exit(1) unless $?.success?
end

task :setup do
  node_json = ENV['NODE'] || 'node.json'
  json = JSON.parse(File.read( File.expand_path("../#{node_json}", __FILE__) ))

  name                  = json['elasticsearch']['node_name']                          rescue nil
  aws_access_key        = json['elasticsearch']['cloud']['aws']['access_key']         rescue nil
  aws_secret_access_key = json['elasticsearch']['cloud']['aws']['secret_key']         rescue nil
  aws_region            = json['elasticsearch']['cloud']['aws']['region']             rescue nil
  aws_group             = json['elasticsearch']['cloud']['ec2']['security_group']     rescue nil

  http_username         = json['elasticsearch']['nginx']['users'][0]['username']      rescue nil
  http_password         = json['elasticsearch']['nginx']['users'][0]['password']      rescue nil

  @args = {}
  @args[:name]                  = ENV['NAME'] || name || 'elasticsearch-test'
  @args[:node_json]             = node_json
  @args[:aws_ssh_key_id]        = ENV['AWS_SSH_KEY_ID'] || 'elasticsearch-test'
  @args[:aws_access_key_id]     = ENV['AWS_ACCESS_KEY_ID'] || aws_access_key
  @args[:aws_secret_access_key] = ENV['AWS_SECRET_ACCESS_KEY'] || aws_secret_access_key
  @args[:aws_region]            = ENV['AWS_REGION'] || aws_region || 'us-east-1'
  @args[:aws_groups]            = ENV['GROUP'] || aws_group || 'elasticsearch-test'
  @args[:aws_flavor]            = ENV['FLAVOR'] || 't1.micro'
  @args[:aws_image]             = ENV['IMAGE'] || 'ami-1624987f'
  @args[:ssh_user]              = ENV['SSH_USER'] || 'ec2-user'
  @args[:ssh_key]               = ENV['SSH_KEY']  || File.expand_path('../tmp/elasticsearch-test.pem', __FILE__)
  @args[:http_username]         = http_username
  @args[:http_password]         = http_password
end
