#!/usr/bin/env ruby
#
# Generates a CSV with RS account, deployment, serverID and tags when provided with
# RS credentials and an account ID.  The account ID can be an enterprise parent.
# If the supplied account ID is an enterprise parent, all child accounts will be
# evaluated as well.
#

require 'rubygems'
require 'logger'
require 'rs_user_policy'
require 'right_api_client'

email = ENV['RSEMAIL'] || 'your@email.com'
pass = ENV['RSPASS'] || 'yourpassword'
acct_id = ENV['RSACCT'] || '12345'
uuid = ENV['RSUUID'] || 'default_rs_uuid'
logger = Logger.new(STDOUT)

logger.info("Looking for any child accounts for account ID #{acct_id}")

multi_client = RsUserPolicy::RightApi::MultiClient.new(email,pass,[acct_id])

multi_client.each do |id,acct|
  acct_name = acct[:resource] ? acct[:resource].name : "Unknown ID: #{id}"
  logger.info("  -- Account #{acct_name}")
  client = acct[:client]
  instances = client.tags.by_tag(:resource_type => "instances", :tags => ["server:uuid=#{uuid}"])
  if instances.size == 0
    logger.warn("    -- No instances with the RightScale UUID (#{uuid}) were found in this account")
  else
    instances.each do |inst_by_tag|
      instance = inst_by_tag.resource.show()
      logger.info("    -- Found instance! HREF: #{instance.href} Name: #{instance.name}")
    end
  end
end