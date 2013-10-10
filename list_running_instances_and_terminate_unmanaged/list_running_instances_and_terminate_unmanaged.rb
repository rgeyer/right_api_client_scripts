#!/usr/bin/env ruby
#

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

instances = 0
unmanaged = 0
multi_client.each do |id,acct|
  acct_name = acct[:resource] ? acct[:resource].name : "Unknown ID: #{id}"
  logger.info("  -- Account #{acct_name}")
  client = acct[:client]
  client.clouds.index.each do |cloud|
    logger.info("    -- #{cloud.name} - #{cloud.href}")
    cloud.show()
    these_unmanaged = []
    these_instances = cloud.instances().index
    these_instances.each do |inst|
      inst.show()
      unless inst.state &&
          !inst.state.empty? &&
          !['inactive','terminated'].include?(inst.state)
        next
      end

      if inst.links.select {|l| l['rel'] == 'parent'}.size == 0
        these_unmanaged << inst
        unmanaged += 1
        logger.warn("      -- Attempting to terminate instance #{inst.name} - #{inst.href} || #{inst.state}")
        inst.terminate()
      else
        instances += 1
      end
    end
    logger.info("      -- #{these_instances.size} total instances")
    logger.info("      -- #{these_unmanaged.size} unmanaged instances")
  end
end

puts "#{unmanaged} grand total unmanaged instances"
puts "#{instances} grand total instances"
