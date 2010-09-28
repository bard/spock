#!/usr/bin/env ruby

# Copyright (C) 2007 by Massimiliano Mirra
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#
# Author: Massimiliano Mirra, <bard [at] hyperstruct [dot] net>


require 'xml/libxslt'
require 'strscan'

INDENT = '  '
NS_EM = 'http://www.mozilla.org/2004/em-rdf#'

class String
  def begins_with?(prefix)
    prefix == slice(0,prefix.length)
  end

  def ends_with?(suffix)
    suffix == slice(-suffix.length..-1)
  end
end


######################################################################
# Main interface

def normalize_update_rdf(filename, ext_id, &block)
  serialize_resource(parse_nt(rdf2nt(filename)), ext_id, &block)
end


######################################################################
# Implementation


# Convert RDF into n-triples form, for easier parsing

def rdf2nt(filename)
  xslt = XML::XSLT.new
  xslt.xml = filename
  xslt.xsl = File.dirname(__FILE__) + '/rdf2nt.xsl'
  xslt.serve
end

def parse_nt(ntriples_dump)
  triples = { }

  ntriples_dump.split("\n").each do |line|
    s = StringScanner.new(line)
    subj = s.scan(/_:id\d+|<[^>]+>/).gsub(/^<|>$/, '')
    s.skip(/\s+/)
    pred = s.scan(/<[^>]+>/).gsub(/^<|>$/, '')
    s.skip(/\s+/)
    obj = s.scan(/_:id\d+|"[^"]*"|<[^>]+>/).gsub(/^<|>$/, '').gsub(/^"|"$/, '')

    triples[subj] ||= []
    triples[subj] << [subj, pred, obj]

    s.skip(/\s+/)
    s.scan(/\./) or raise RuntimeError
  end

  triples
end

# Translated from mccoy/chrome/content/rdfserializer.js

def serialize_resource(ds, subj, indent = '', &block)
  if is_seq(ds, subj)
    type = 'Seq'
    container = make_seq(ds, subj)
  elsif is_alt(ds, subj)
    type = 'Alt'
    container = make_alt(ds, subj)
  elsif is_bag(ds, subj)
    type = 'Bag'
    container = make_bag(ds, subj)
  else
    type = 'Description'
    container = nil
  end

  result = indent + '<RDF:' + type
  unless is_anonymous_resource(subj)
    result << ' about="' << subj << '"'
  end
  result << ">\n"

  if container
    result << serialize_container_items(ds, container, indent + INDENT, &block)
  end

  result << serialize_resource_properties(ds, subj, indent + INDENT, &block)

  result << indent << '</RDF:' << type << ">\n"
  result
end

def serialize_resource_properties(ds, subj, indent, &block)
  result = ''
  if not ds[subj]
    return result
  end
    
  items = []
  for resource in ds[subj]
    subj, pred, obj = resource

    if block_given?
      obj = yield(subj, pred, obj) || obj
    end

    pred.begins_with?(NS_EM) or next
    #pred.ends_with?('#signature') and next
    
    prop = pred.slice(NS_EM.length..-1)
    
    if obj.begins_with?('_')
      item = indent + '<em:' + prop + ">\n"
      item << serialize_resource(ds, obj, indent + INDENT, &block)
      item << indent << "</em:" + prop + ">\n"
      items.push(item)
    else
      items.push(indent + '<em:' + prop + '>' + escape_entities(value_of(obj)) + '</em:' + prop + ">\n")
    end
  end
  result << items.sort.join
  
  result
end

def escape_entities(s)
  s                             # XXX todo
end

def value_of(s)
  s                             # XXX todo
end

def serialize_container_items(ds, container, indent, &block)
  result = ''
  for resource in container
    subj, pred, obj = resource

    result << indent << "<RDF:li>\n"
    result << serialize_resource(ds, subj, indent + INDENT, &block)
    result << indent << "</RDF:li>\n"
  end
  result
end

def is_anonymous_resource(subj)
  subj[0,1] == '_'
end

def is_seq(ds, subj)
  ds[subj] &&
    ds[subj].any? {|subj, pred, obj| obj == "http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq"}
end

def is_alt(ds, subj)
  ds[subj] &&
    ds[subj].any? {|subj, pred, obj| obj == "http://www.w3.org/1999/02/22-rdf-syntax-ns#Alt"}
end

def is_bag(ds, subj)
  ds[subj] &&
    ds[subj].any? {|subj, pred, obj| obj == "http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag"}
end

def make_seq(ds, subj)
  ds[subj].select do |subj, pred, obj|
    obj != "http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq"
  end.map do |subj, pred, obj|
    obj
  end
end

def make_alt(ds, resource)
  raise Error.new('Not implemented')
end

def make_bag(ds, resource)
  raise Error.new('Not implemented')
end


######################################################################
# Run as standalone

if __FILE__ == $0
  filename, ext_id = *ARGV
  unless filename and ext_id
    STDERR.puts "#{File.basename($0)}: no update.rdf given."
    abort
  end
  
  puts normalize_update_rdf(filename, ext_id)
end

