#!/usr/bin/env ruby
#
# Given a JSON file with a hash of RightScale resources, terminate/deletes them in the
# appropriate order
#

require 'rubygems'
require 'json'
require 'logger'
require 'right_api_client'

email = ENV['RSEMAIL'] || 'your@email.com'
pass = ENV['RSPASS'] || 'yourpassword'
acct_id = ENV['RSACCT'] || '12345'
filename = ENV['PLECO_ALGAE_FILE'] || 'algae.js'
$logger = Logger.new(STDOUT)
valid_resources = ['server','server_array','deployment','ssh_key','security_group']

algae_file_format = <<EOF

The Algae file is expected to be a JSON hash where keys are the resource type and values
are an array of resources of that type.

Valid resource types are;
#{valid_resources.join(',')}

Example
{
  "server": ["/api/servers/1","/api/servers/2"],
  "server_array": ["/api/server_arrays/1"],
  "deployment": ["/api/deployments/1"],
  "ssh_key": ["/api/clouds/1/ssh_keys/1"],
  "security_group": ["/api/clouds/1/security_groups/1"]
}
EOF

$client = RightApi::Client.new(:email => email, :password => pass, :account_id => acct_id)

def lookup_resource(path)
  # TODO: Catch not found exception and skip or otherwise handle
  $logger.info("Looking up resource at path #{path}")
  $client.resource(path)
end

$logger.info("Search for JSON file at path #{filename}")
unless File.exists?(filename)
  $logger.error("JSON file #{filename} not found, please set ENV['PLECO_ALGAE_FILE'] correctly")
  exit 1
end

algae = {}
begin
  algae = JSON.load(File.read(filename))
rescue Exception => e
  $logger.error(e)
  exit 1
end

# Some simple validation of the JSON contents
unless algae.is_a?(Hash)
  $logger.error("Algae file is not a hash #{algae_file_format}")
  exit 1
end

unknown_resources = algae.keys - valid_resources
if unknown_resources.size != 0
  $logger.warn("Algae file contains the following unrecognized resource types, they will not be processed.  Unknown resource types: (#{unknown_resources.join(',')})")
end

valid_resources.each do |resource_type|
  if algae.key?(resource_type)
    done_with_this_resource = true
    algae[resource_type].each do |resource_href|
      case resource_type
        when "server"
          # TODO: Terminate that muthah suckah
          resource = lookup_resource(resource_href)
          state = resource.show().state
          $logger.info("Server was #{state}")
          if ["stranded in booting", "pending", "operational", "stopped", "provisioned"].include?(state)
            $logger.info("Server was #{state}, attempting to terminate")
            resource.terminate()
          end

          done_with_this_resource = (state == "inactive")

        when "server_array"
          # TODO: Terminate all instances, disable array
          resource = lookup_resource(resource_href)

        when "security_group"
          # Skip it
          next

        else
          resource = lookup_resource(resource_href)
      end
      if done_with_this_resource
        $logger.info("Destroying #{resource_type} at path #{resource_href}")
        resource.destroy()
      end
    end

    unless done_with_this_resource
      $logger.info("Not quite done cleaning up #{resource_type}s, waiting 20 seconds and going again.")
      Kernel.sleep(20)
      redo
    end
  end
end

if algae.key?("security_group")
  $logger.info("Iterating over security groups to destroy rules")
  algae["security_group"].each do |sghref|
    sg = lookup_resource(sghref)
    sg.security_group_rules.index.each do |sgrule|
      $logger.info("Destroying security group rule #{sgrule.href}")
      sgrule.destroy()
    end
  end

  $logger.info("Iterating over security groups to destroy them, now that they have no rules")
  algae["security_group"].each do |sghref|
    sg = lookup_resource(sghref)
    sg.destroy()
  end
end