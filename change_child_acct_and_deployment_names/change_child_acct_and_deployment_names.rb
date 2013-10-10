#!/usr/bin/env ruby
#
# Reads and writes RightScale account and deployment names from JSON.  Useful for
# updating demo accounts to names which are appropriate for the customer you're
# demoing to.
#
# It always discovers the current name(s) of accounts and deployments and puts them
# in a "discovered.json" file.
#
# You can specify an input file which will be used to rename the accounts and
# deployments using the --source flag
#

require 'json'
require 'rubygems'
require 'logger'
require 'trollop'
require 'rs_user_policy'
require 'right_api_client'

email = ENV['RSEMAIL'] || 'your@email.com'
pass = ENV['RSPASS'] || 'yourpassword'
acct_id = ENV['RSACCT'] || '12345'
source = false

opts = Trollop::options do
  banner = "Reads and write RightScale account and deployment names from JSON"

  opt :source, "A JSON file containing a set of account and deployment names you want to set. See the generated discovered.json file for syntax and format", :type => :string
end


if opts[:source]
  source = JSON.parse(File.read(opts[:source]))
end

logger = Logger.new(STDOUT)

logger.info("Looking for any child accounts for account ID #{acct_id}")

multi_client = RsUserPolicy::RightApi::MultiClient.new(email,pass,[acct_id])

output_json = {}

multi_client.each do |id,acct|
  client = acct[:client]
  acct_name = acct[:resource] ? acct[:resource].name : "Unknown ID: #{id}"
  acct_href = "/api/accounts/#{id}"
  output_json[acct_href] = {
      'name' => acct_name,
      'deployments' => {}
  }
  if source && source.key?(acct_href) && acct_name != source[acct_href]['name']
    if acct.key?(:parent)
      parent_client = RightApi::Client.new(:email => email, :password => pass, :account_id => acct[:parent])
      logger.info("  -- Changing account #{id} name from #{acct_name} to #{source[acct_href]['name']}")
      parent_client.child_accounts(:id => id).update({:child_account => {:name => source[acct_href]['name']}})
    else
      logger.warn("  -- Account ID #{id} does not appear to be a child of any other account, and therefore it's name can not be changed")
    end
  end
  logger.info("    -- Searching for deployments in - #{acct_name}")
  client.deployments.index.each do |deployment|
    deployment.show()
    depl_name = deployment.name
    depl_href = deployment.href
    output_json[acct_href]['deployments'][depl_href] = depl_name
    if source && source.key?(acct_href) && source[acct_href]['deployments'].key?(depl_href) && depl_name != source[acct_href]['deployments'][depl_href]
      logger.info("      -- Changing deployment #{depl_href} name from #{depl_name} to #{source[acct_href]['deployments'][depl_href]}")
      depl_id = RsUserPolicy::Utilities.id_from_href(depl_href).to_i
      client.deployments(:id => depl_id).update({:deployment => {:name => source[acct_href]['deployments'][depl_href]}})
    end
  end
end

File.open('discovered.json', 'w') {|f| f.write(JSON.pretty_generate(output_json))}