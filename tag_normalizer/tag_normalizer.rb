#!/usr/bin/env ruby
#
#

require 'json'
require 'rubygems'
require 'logger'

refresh_token = ENV['RSREFRESHTOKEN'] || 'your@email.com'
shard = ENV['RSSHARD'] || 'us-3.rightscale.com'
acct_id = ENV['RSACCT'] || '12345'
logger = Logger.new(STDOUT)

# TODO: Safety check for rsc?
file = `rsc -r #{refresh_token} -a #{acct_id} -h #{shard} cm16 index /api/instances view=full`
instances_json = JSON.parse(file)
normalized = {}
instances_json.each do |instance|
  instance['tags'].each do |tag|
    parts = /(?<namespace>.*):(?<predicate>.*)=(?<value>.*)/.match(tag)
    normalized_predicate = parts['predicate'].gsub(/[\W_]/,'').downcase
    normalized[normalized_predicate] = [] if !normalized.key?(normalized_predicate)
    normalized[normalized_predicate] << {instance: instance, tag_val: parts['value']}
  end
end

for_output = {}
normalized.each do |k,v|
  normalized_ns_and_predicate = "normalized:#{k}"
  for_output[normalized_ns_and_predicate] = [] if !for_output[normalized_ns_and_predicate]
  v.each do |instance_of_normalized_tag|
    for_output[normalized_ns_and_predicate] << {
      instance_href: instance_of_normalized_tag[:instance]['href'],
      normalized_tag: "normalized:#{k}=#{instance_of_normalized_tag[:tag_val]}"
    }
  end
end

puts JSON.pretty_generate(for_output)
