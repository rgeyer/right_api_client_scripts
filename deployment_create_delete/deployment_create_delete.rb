#!/usr/bin/env ruby
#
# Reads a text file which contains a list of deployment names. File format is
# one deployment name per line. Will create all the deployments listed with
# additional tags deployment:auto_generated=true,
# deployment:batch_timestamp=<ISO 8601 timestamp>
#
# By default the text file searched for will be "deployments.txt" in the CWD
# but can be specified with the --deployments option
#
# Can also delete all deployments found in the file by specifying --action delete

require 'date'
require 'json'
require 'rubygems'
require 'logger'
require 'trollop'
require 'right_api_client'

email = ENV['RSEMAIL'] || 'your@email.com'
pass = ENV['RSPASS'] || 'yourpassword'
acct_id = ENV['RSACCT'] || '12345'

opts = Trollop::options do
  banner = "Creates or deletes deployments by names provided in a line return delimited file"

  opt :deployments, "A text file containing one deployment name per line", :default => "deployments.txt"
  opt :action, "What to do, one of 'create' or 'delete'", :default => "create"
end

deployment_file = File.expand_path(opts[:deployments] || 'deployments.txt', Dir.pwd)
action = opts[:action] || 'create'

logger = Logger.new(STDOUT)

logger.info("Reading deployments file - #{deployment_file}")

deployments_txt = File.read(deployment_file)
deployments = deployments_txt.split(/\r\n|\n/)

logger.info("Found #{deployments.size} deployments in deployments file to #{action}")

timestamp = DateTime.now

logger.info("Batch timestamp is - #{timestamp.iso8601}")

client = RightApi::Client.new(:email => email, :password => pass, :account_id => acct_id, :timeout => nil)

case action
when 'create'
  deployment_resource_hrefs = []
  deployments.each do |deployment_name|
    logger.info("Creating deployment - #{deployment_name}")
    begin
      deployment = client.deployments.create(deployment: {name: deployment_name})
      deployment_resource_hrefs << deployment.href
    rescue RightApi::ApiError => e
      logger.warn("Failed to create deployment - #{deployment_name}\r\nError: #{e}")
    end
  end
  if deployment_resource_hrefs.size > 0
    logger.info("Tagging #{deployment_resource_hrefs.size} newly created deployments")
    client.tags.multi_add(
      resource_hrefs: deployment_resource_hrefs,
      tags: ["deployment:auto_generated=true","deployment:batch_timestamp=#{timestamp.iso8601}"]
    )
  end
when 'delete'
  deployments.each do |deployment_name|
    logger.info("Searching for deployment - #{deployment_name}")
    found_deployment = client.deployments.index(filter: ["name==#{deployment_name}"])
    if found_deployment && found_deployment.size == 1
      logger.info("Deleting deployment - #{deployment_name}")
      found_deployment.first.destroy
    else
      logger.info("Deployment not found, skipping delete - #{deployment_name}")
    end
  end
else
  logger.info("Dunno what to do with action (#{action})")
end
