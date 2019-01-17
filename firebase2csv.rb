#!/usr/bin/env ruby

require 'json'
require 'csv'

json = JSON.parse(File.read(ARGV[0]))

talks = json['talks'].values

out = CSV.generate do |csv|
  keys = talks.first.keys
  csv << keys
  talks.each do |row|
    csv << row.values_at(*keys)
  end
end

puts out
