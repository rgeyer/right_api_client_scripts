#!/usr/bin/env ruby
#
# Launches a single instance of a LAMP All-In-One Trial with MySQL 5.5 (v13.5.2-LTS)
#

require 'rubygems'
require 'json'
require 'logger'
require 'timeout'
require 'right_api_client'

email     = ENV['RSEMAIL'] || 'your@email.com'
pass      = ENV['RSPASS'] || 'yourpassword'
acct_id   = ENV['RSACCT'] || '12345'
cloud_id  = ENV['CLOUD_ID'] || '1'

st_trial_pub_id = '183965'
st_pub_id       = '183963'

logger            = Logger.new(STDOUT)
client            = RightApi::Client.new(:email => email, :password => pass, :account_id => acct_id)
provisioned_hash  = {}
time              = Time.now
timestamp         = time.to_i

# Import the publication and get the ServerTemplate href
logger.info("Importing LAMP All-In-One Trial with MySQL 5.5 (v13.5.2-LTS) ServerTemplate")
st_href = client.publications(:id => st_trial_pub_id).import().href
logger.info("ServerTemplate href is #{st_href}")

# Get the cloud
logger.info("Searching for cloud with ID #{cloud_id}")
cloud = client.clouds(:id => cloud_id).show()

# Prep the server create params hash
server_params_hash = {
  :name => "LAMP All-in-One",
  :instance => {
    :cloud_href => cloud.href,
    :server_template_href => st_href
  }
}

begin
  # Create a deployment
  deployment_name = "AIO Trial CLI-#{timestamp}"
  deployment = client.deployments.create(:deployment => {:name => deployment_name})
  provisioned_hash["deployment"] = [deployment.href]
  logger.info("Created deployment named #{deployment_name} at #{deployment.href}")

  # Create an SSH key (if the cloud supports it)
  if cloud.links.select {|l| l["rel"] == "ssh_keys"}.size == 1
    ssh_key_name = "ssh_key-#{timestamp}"
    ssh_key = cloud.ssh_keys.create(:ssh_key => {:name => ssh_key_name})
    provisioned_hash["ssh_key"] = [ssh_key.href]
    logger.info("Created ssh_key named #{ssh_key_name} at #{ssh_key.href}")
    server_params_hash[:instance][:ssh_key_href] = ssh_key.href
  else
    logger.info("The cloud #{cloud.name} does not support SSH keys, skipping creation")
  end

  # Create a security group (if the cloud supports it)
  if cloud.links.select {|l| l["rel"] == "security_groups"}.size == 1
    security_group_name = "default-#{timestamp}"
    security_group = cloud.security_groups.create(:security_group => {:name => security_group_name})
    provisioned_hash["security_group"] = [security_group.href]
    logger.info("Created security_group named #{security_group_name} at #{security_group.href}")
    server_params_hash[:instance][:security_group_hrefs] = [security_group.href]

    # Allow ssh ingress
    security_group.show.security_group_rules.create(
        :security_group_rule => {
            :cidr_ips => "0.0.0.0/0",
            :direction => "ingress",
            :protocol => "tcp",
            :protocol_details => {
                :start_port => "22",
                :end_port => "22"
            },
            :source_type => "cidr_ips"
        }
    )
    logger.info("Added ssh security group rule")

    # Allow http ingress
    security_group.show.security_group_rules.create(
        :security_group_rule => {
            :cidr_ips => "0.0.0.0/0",
            :direction => "ingress",
            :protocol => "tcp",
            :protocol_details => {
                :start_port => "80",
                :end_port => "80"
            },
            :source_type => "cidr_ips"
        }
    )
    logger.info("Added http security group rule")
  else
    logger.info("The cloud #{cloud.name} does not support security groups, skipping creation")
  end

  # Add the server
  server = deployment.show.servers.create({:server => server_params_hash})
  provisioned_hash[:server] = [server.href]
  logger.info("Created server named #{provisioned_hash[:name]} at #{server.href}")

  status = Timeout::timeout(1200) {
    server.launch()
    begin
      state = server.show().state
      logger.info("Server state is #{state}...  Waiting for 20 seconds")
      Kernel.sleep(20)
    end until ["stranded in booting","operational"].include?(state)
  }

  case server.show().state
    when "operational"
      logger.info("Successfully launched #{server.show().name}")
    when "stranded in booting"
      #audit_entry = client.audit_entries(
      #  :filter => ["auditee_href==#{server.href}"],
      #  :start_date => time.strftime("%Y/%m/%d %H:%M:%S"),
      #  :end_date => Time.now.strftime("%Y/%m/%d %H:%M:%S")
      #)
      logger.error("Oops, there was a problem with getting #{server.show().name} operational, go check the audit entries in the dashboard please!.")
  end

rescue Exception => e
  logger.error(e)
ensure
  File.open("algae.js","w") do |file|
    file.write(JSON.generate(provisioned_hash))
  end
end