#!/usr/bin/env ruby
#
# Generates a CSV with RS account, deployment, serverID and tags when provided with
# RS credentials and an account ID.  The account ID can be an enterprise parent.
# If the supplied account ID is an enterprise parent, all child accounts will be
# evaluated as well.
#

require 'csv'
require 'rubygems'
require 'logger'
require 'rs_user_policy'
require 'right_api_client'

email = ENV['RSEMAIL'] || 'your@email.com'
pass = ENV['RSPASS'] || 'yourpassword'
acct_id = ENV['RSACCT'] || '12345'
logger = Logger.new(STDOUT)

logger.info("Looking for any child accounts for account ID #{acct_id}")

multi_client = RsUserPolicy::RightApi::MultiClient.new(email,pass,[acct_id])

CSV.open("tags_by_server.csv", "wb") do |csv|
  csv << ["Account Name","Account ID","Deployment Name","Deployment HREF","Server Name","Server HREF","Tags"]
  multi_client.each do |id,acct|
    client = acct[:client]
    instance_hash = {}
    account_name = acct[:resource] ? acct[:resource].name : "Unknown ID: #{id}"
    logger.info(" -- Searching for deployments in - #{account_name}")
    client.deployments.index.each do |deployment|
      deployment.show()
      depl_name = deployment.name
      depl_href = deployment.href
      logger.info("   -- Searching for servers in deployment #{depl_name}")
      deployment.servers.index.each do |server|
        server.show()
        current_instance_link = server.links.select { |link| link['rel'] == 'current_instance' }
        if current_instance_link.size > 0
          instance_hash[current_instance_link.first()['href']] = [account_name,id,depl_name,depl_href,server.name,server.href]
        end
      end
    end

    unless instance_hash.size > 0
      logger.warn("   -- There doesn't seem to be any running instances in #{account_name}.")
      next
    end

    tags_by_href = client.tags.by_resource(:resource_hrefs => instance_hash.keys)

    tags_by_href.each do |tags|
      if instance_hash.key? tags.links.first()['href']
        instance_href = tags.links.first()['href']
        cvsrow = instance_hash[instance_href]
        cvsrow << tags.tags.collect {|tag| tag['name']}.join(' ')
        csv << cvsrow
      end
    end
  end
end
