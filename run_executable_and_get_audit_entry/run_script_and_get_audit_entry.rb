#!/usr/bin/env ruby

require 'rubygems'
require 'date'
require 'right_api_client'

email = ENV['RSEMAIL'] || 'your@email.com'
pass = ENV['RSPASS'] || 'yourpassword'
acct_id = ENV['RSACCT'] || '12345'
instance_href = ENV['RSINSTANCEHREF'] || 'href of instance to run script on'
script_href = ENV['RSSCRIPTHREF'] || 'href of a non-action script to run'

client = RightApi::Client.new(
  :email => email,
  :password => pass,
  :account_id => acct_id
)

instance = client.resource(instance_href)

start_time = ::DateTime.now

task = instance.run_executable(
  :right_script_href => script_href)

loop do
  status = task.show.summary
  if status =~ /^completed:.*/
    puts "Task completed"
    break
  end
  puts "Task still working, waiting 5 seconds before checking again..."
  sleep 5
end

end_time = ::DateTime.now

startstr = start_time.strftime("%Y/%m/%d %H:%M:%S %z")
endstr = end_time.strftime("%Y/%m/%d %H:%M:%S %z")

entries = client.audit_entries.index(
  :start_date => startstr,
  :end_date => endstr,
  :limit => 1,
  :auditee_href => instance_href
)

entry_href = entries.first.show.detail.href

href = "https://us-4.rightscale.com#{entry_href}"

detail_req = RestClient::Request.new(
  :url => href,
  :method => :get,
  :cookies => client.cookies,
  :headers => {"X_API_VERSION"=>"1.5"}
)
detail_resp = detail_req.execute

puts detail_resp.body

puts "All Done"
