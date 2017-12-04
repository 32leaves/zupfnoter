
require 'opal'
require 'nodejs'
#require 'opal-jquery'
require 'vector2d'
#require 'opal-neatjson'
#require 'neatjson_js'
require 'opal-ajv'
#require 'math'

#require 'consolelogger'
require 'harpnotes'
require 'abc_to_harpnotes_factory'
require 'abc2svg_to_harpnotes'

#require 'node_modules/jspdf/dist/jspdf.min'
#require 'opal-jspdf'
require 'opal-jszip'
#require 'opal-musicaljs'
#require 'svg_engine'
#require 'pdf_engine'
require 'i18n'
require 'init_conf'
#require 'command-controller'

# require 'controller_command_definitions'
#require 'harpnote_player'
#require 'text_pane'
# require 'opal-dropboxjs'
#require 'opal-jqconsole'
require 'confstack2'
require 'opal-abc2svg'
# require 'opal-w2ui'
require 'version'
# require 'user-interface.js'
# require 'config-form'
# require 'snippet_editor'
require 'abc2svg-1.js'

require 'controller-cli'

puts ARGV

puts "processing #{ARGV.first}"

begin
abctext = File.read(ARGV.first)
rescue Exception
  puts "mist"
  end

File.open(%Q{#{ARGV.first}.out}, "w") do |f|
  f.puts abctext
  f.puts VERSION
end

puts "done"