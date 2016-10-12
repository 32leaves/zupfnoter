$:.unshift File.dirname(__FILE__)
require 'redcarpet'
require 'json'

require 'neatjson'
require 'i18n'
require 'init_conf'
require 'confstack'

class ConfDocProvider

  attr_reader :entries_html, :entries_md

  def initialize
    @renderer     = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    @entries_md   = {}
    @entries_html = {}
  end

  def insert (key, markdown)
    @entries_md[key]   = markdown
    @entries_html[key] = @renderer.render(markdown)
  end

  def to_json
    JSON.neat_generate(@entries_html)
  end

end


class Document
  def self.ready?

  end
end


def get_example(conf, key)
  neatjson_options = {wrap:          60, aligned: true, after_comma: 1, after_colon_1: 1, after_colon_n: 1, before_colon_n: 1, sorted: true,
                      explicit_sort: [[:produce, :annotations, :restposition, :default, :repeatstart, :repeatend, :extract,
                                       :title, :voices, :flowlines, :subflowlines, :synchlines, :jumplines, :repeatsigns, :layoutlines, :barnumbers, :countnotes, :legend, :notes, :lyrics, :nonflowrest, :tuplet, :layout,
                                       :annotation, :partname, :variantend, :countnote, :stringnames, # sort within notebound
                                       :limit_a3, :LINE_THIN, :LINE_MEDIUM, :LINE_THICK, :ELLIPSE_SIZE, :REST_SIZE, # sort within laoyut
                                       "0", "1", "2", "3", "4", "5", "6", :verses, # extracts
                                       :cp1, :cp2, :shape, :pos, :hpos, :vpos, :spos, :text, :style, :marks # tuplets annotations
                                      ],
                                      []],
  }
  k                = key.split(".").last
  %Q{
"#{k}": #{JSON.neat_generate(conf[key], neatjson_options)}
  }.split("\n").map { |l| "        #{l}" }.join("\n")
end

ignore_patterns  = [/^neatjson/, /abc_parser^*/, /^extract\.[235].*/, /^defaults.*/, /^templates.*/, /^annotations.*/, /^extract\.[1234]/,
                    /^layout.*/
]
produce_patterns = [/annotations\.vl/, /^templates\.tuplets/]

a=ConfDocProvider.new

File.open("localization/help_de-de.md").read.scan(/## ([^\n]*)([^#]*)/).each do |match|
  a.insert(match[0], match[1])
end

#-- generate helptexts

File.open("../public/locale/conf-help_de-de.json", "w") do |f|
  f.puts a.to_json
end


#-- generate configuration doc

$conf_helptext = a.entries_html

ignore_patterns  = [/^neatjson.*/, /abc_parser.*/, /^extract\.[235].*/, /^defaults.*/, /^templates.*/, /^annotations.*/, /^extract\.[1234]/,
                    /^layout.*/, /^extract\.0$/
]
produce_patterns = [/annotations\.vl/, /^templates\.tuplets/, /^extract$/, /^templates/, /^annotations/]


locale = JSON.parse(File.read('../public/locale/de-de.json'))

$conf = Confstack.new(false)
$conf.push(JSON.parse(InitConf.init_conf.to_json))

ignore_keys  = $conf.keys.select { |k| ignore_patterns.select { |ik| k.match(ik) }.count > 0 }
produce_keys = $conf.keys.select { |k| produce_patterns.select { |ik| k.match(ik) }.count > 0 }
show_keys    = ($conf.keys - ignore_keys + produce_keys).uniq.sort_by { |k| k.gsub('templates', 'extract.0') }

mdhelp = []
show_keys.each do |key|
  show_key = key #.gsub(/^templates\.([a-z]+)(\.)/){|m| "extract.0.#{$1}.0."}

  candidate_keys = I18n.get_candidate_keys(key)
  candidates     = candidate_keys.map { |c| a.entries_md[c.join('.')] }

  helptext = candidates.compact.first || %Q{TODO: Helptext für #{key} einfügen }

  result = %Q{

## `#{show_key}` - #{locale['phrases'][key.split(".").last]}

  #{helptext}

  #{get_example($conf, key)}
  }
  mdhelp.push result
end


File.open("xxx.md", "w") do |f|
  f.puts "# Konfiguration der Ausgabe"
  f.puts %Q{

Dieses Kapitel beschreibt die Konfiguration der Erstellung der Unterlegnotenblätter. Das Kapitel ist als Referenz aufgebaut.
Die einzelnen Konfigurationsparameter werden in alphabetischer Reihenfolge aufgeführt. Bei den einzelnen Parametern
wird der Text der Online-Hilfe, sowie die Voreinstellungen des Systems dargestellt.

>**Hinweis**: Auch wenn in den Bildschirmmasken die Namen der Konfigurationsparameter übersetzt sind, so basiert
>diese Referenz den englischen Namen.

>**Hinweis**: Manche Konfigurationsparameter treten können mehrfach auftreten (z.B. `extract`). In diesem Kapitel wird
>dann immer die Instanz mit der Nr. 0 (z.B. `extract.0`) beschrieben.
          }
  f.puts mdhelp
end


# ---- generate missing locales


require './controller.rb'
require './confstack.rb'
require './neatjson.rb'


a = InitConf.init_conf
b = Confstack.new(false)
b.push(JSON.parse(a.to_json))

knownkeys = JSON.parse(File.read("../public/locale/de-de.json"))
keys      = []
Dir['user-interface.js'].each do |file|
  File.read(file).scan(/(caption|text|tooltip):\s*["']([^'"]*)["']/) do |clazz, key|
    key = key.gsub("\\n", "\n")
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
  File.read(file).scan(/(w2utils\.lang\()["']([^'"]*)["']\)/) do |clazz, key|
    key = key.gsub("\\n", "\n")
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
end

Dir['*.rb'].each do |file|
  File.read(file).scan(/(I18n\.t)\(['"]([^'"]+)['"]/) do |clazz, key|
    key = key.gsub("\\n", "\n")
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
end

b.keys.each do |key|
  key.split(".").each do |key|
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
end

File.open("x.locales.template", "w") do |f|
  f.puts keys.to_a.map { |v| %Q{"#{v}": "**--#{v}"} }.uniq.sort_by { |i| i.upcase }.join(",\n")
end
