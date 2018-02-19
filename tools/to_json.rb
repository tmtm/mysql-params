#!/usr/bin/env ruby

require 'pathname'
require 'json'

vers = {}
dir = Pathname(__dir__)+ '..'
(dir + 'mysqld').each_child do |txt|
  ver = txt.basename('.txt')
  vers[ver] = "json/mysqld-#{ver}.json"
  params = txt.read.split(/^-+ -+\n/).last.split(/^$/).first.lines.map do |line|
    line.chomp.split(/ +/, 2)
  end.to_h
  (dir + "json/mysqld-#{ver}.json").write params.to_json
end
(dir + "json/mysqld.json").write vers.to_json
