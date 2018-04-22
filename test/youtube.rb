#!/usr/bin/env ruby

require_relative '../lib/youtube/api/video_v3.rb'

ids = [
  #  "08qd-vsHbaY",
  #  "oACQyGiM9Lg",
  #  "JT9HydSMSHo",
  #  "e5xnyClQ_kk",
  #  "08qd-vsHbaY",
  'JT9HydSMSHo',
  'JdSMSHo'
]

api = YouTube::API::VideoV3.new
ids.each do |id|
  video = api.get_video(id)
  puts video.json
  puts "#{video.title} | #{video.duration} | #{video.view_count.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse} views | #{video.description}"
end
