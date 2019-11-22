#!/usr/bin/env ruby

require 'pathname'
require 'json'

vers = {}
dir = Pathname(__dir__)+ '..'
(dir + 'mysqld/data').each_child do |txt|
  ver = txt.basename('.txt').to_s
  vers[ver] = "json/mysqld-#{ver}.json"
  params = txt.read.split(/^-+ -+\n/).last.split(/^$/).first.lines.map do |line|
    name, value = line.chomp.split(/ +/, 2)
    [name.gsub(/_/, '-'), value]
  end.to_h
  (dir + "mysqld/json/mysqld-#{ver}.json").write params.to_json
end
(dir + "mysqld/json/mysqld.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
