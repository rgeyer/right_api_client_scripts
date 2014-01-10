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
require 'right_api_client'

email = ENV['RSEMAIL'] || 'your@email.com'
pass = ENV['RSPASS'] || 'yourpassword'
acct_id = ENV['RSACCT'] || '12345'
logger = Logger.new(STDOUT)

client = RightApi::Client.new(:email => email, :password => pass, :account_id => acct_id)

instance_hash = {}

clouds = client.clouds.index

logger.info("Operating on #{clouds.size} Clouds")

clouds.each do |cloud|
  instances = cloud.instances.index(:filter => ['state<>inactive'], :view => 'extended')
  logger.info("Found #{instances.count} that are either running or provisioned for cloud #{cloud.name}")
  instances.each do |instance|
    instance_type = instance.instance_type.show
    if instance_hash.key?(instance_type.name)
      instance_hash[instance_type.name] += 1
    else
      instance_hash[instance_type.name] = 1
    end
  end
end

puts instance_hash