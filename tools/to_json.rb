#!/usr/bin/env ruby
# coding: utf-8

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
      [param, "○"]
    end.to_h
    (dir + "json/#{ver}.json").write params.to_json
  end
  (dir + "json/version.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
end

['privilege'].each do |name|
  vers = {}
  dir = Pathname(__dir__)+'..'+name
  FileUtils.mkdir_p(dir + 'json')
  (dir + 'data').each_child do |txt|
    ver = txt.basename('.txt').to_s
    vers[ver] = "json/#{ver}.json"
    params = txt.read.lines[1..-1].map do |line|
      param = line.split.first
      if param =~ /_priv/
        param = $`.upcase.tr('_', ' ')
        param = case param
                when 'CREATE TMP TABLE'
                  'CREATE TEMPORARY TABLES'
                when 'GRANT'
                  'GRANT OPTION'
                when 'REPL CLIENT'
                  'REPLICATION CLIENT'
                when 'REPL SLAVE'
                  'REPLICATION SLAVE'
                when 'SOHW DB'
                  'SHOW DATABASES'
                else
                  param
                end
      elsif param == 'Proxied_user'
        param = 'PROXY'
      else
        next
      end
      [param, "○"]
    end.compact.to_h
    txt.read.each_line do |line|
      if line =~ /GRANT (.*) ON .* WITH (GRANT OPTION)/
        [$1, $2].join(',').split(/, */).each do |param|
          params[param] = '○'
        end
      end
    end
    params.delete('ALL PRIVILEGES')
    (dir + "json/#{ver}.json").write params.to_json
  end
  (dir + "json/version.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
end

['function'].each do |name|
  vers = {}
  dir = Pathname(__dir__)+'..'+name
  FileUtils.mkdir_p(dir + 'json')
  (dir + 'data').each_child do |txt|
    ver = txt.basename('.txt').to_s
    vers[ver] = "json/#{ver}.json"
    params = txt.read.lines.map do |line|
      param = line.chomp
      [param, "○"]
    end.to_h
    (dir + "json/#{ver}.json").write params.to_json
  end
  (dir + "json/version.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
end

['ischema', 'pschema'].each do |name|
  vers = {}
  dir = Pathname(__dir__)+'..'+name
  FileUtils.mkdir_p(dir + 'json')
  (dir + 'data').each_child do |txt|
    ver = txt.basename('.txt').to_s
    vers[ver] = "json/#{ver}.json"
    params = txt.read.lines.map do |line|
      param = line.chomp.split.join('.')
      [param, "○"]
    end.to_h
    (dir + "json/#{ver}.json").write params.to_json
  end
  (dir + "json/version.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
end

['error'].each do |name|
  vers = {}
  dir = Pathname(__dir__)+'..'+name
  FileUtils.mkdir_p(dir + 'json')
  (dir + 'data').each_child do |txt|
    ver = txt.basename('.txt').to_s
    vers[ver] = "json/#{ver}.json"
    params = txt.read.lines.map do |line|
      line.sub!(/^MySQL error code (MY-)?/, '')
      num, msg = line.chomp.split(/ +/, 2)
      ["%05d"%num.to_i, msg.gsub(/\\n/, "\n")]
    end.to_h
    (dir + "json/#{ver}.json").write params.to_json
  end
  (dir + "json/version.json").write vers.sort_by{|k, v| k.split('.').map(&:to_i) }.reverse.to_h.to_json
end
