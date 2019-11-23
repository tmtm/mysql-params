#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'json'

['mysqld', 'mysql'].each do |name|
  vers = {}
  dir = Pathname(__dir__)+'..'+name
  FileUtils.mkdir_p(dir + 'json')
  (dir + 'data').each_child do |txt|
    ver = txt.basename('.txt').to_s
    vers[ver] = "json/#{ver}.json"
    params = txt.read.split(/^-+ -+\n/).last.split(/^$/).first.lines.map do |line|
      name, value = line.chomp.split(/ +/, 2)
      [name.gsub(/_/, '-'), value]
    end.to_h
    (dir + "json/#{ver}.json").write params.to_json
  end
  (dir + "json/version.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
end

['charset', 'collation', 'status'].each do |name|
  vers = {}
  dir = Pathname(__dir__)+'..'+name
  FileUtils.mkdir_p(dir + 'json')
  (dir + 'data').each_child do |txt|
    ver = txt.basename('.txt').to_s
    vers[ver] = "json/#{ver}.json"
    params = txt.read.lines[1..-1].map do |line|
      param = line.split.first
      [param, param]
    end.to_h
    (dir + "json/#{ver}.json").write params.to_json
  end
  (dir + "json/version.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
end
