class Controller
  private

  def _report_error_from_promise (errormessage)
    $log.error errormessage
    call_consumers(:error_alert)
  end

  def __ic_01_internal_commands
    $log.info("registering commands")
    @commands.add_command(:help) do |c|
      c.undoable = false

      c.set_help do
        "this help";
      end

      c.as_action do
        $log.message("<pre>#{@commands.help_string_style.join("\n")}</pre>")
      end
    end

    @commands.add_command(:view) do |command|

      command.add_parameter(:view, :integer) do |p|
        p.set_default { @systemstatus[:view] }
        p.set_help { "id of the view to be used for preview [#{@systemstatus[:view]}]" }
      end

      command.set_help { "set current view  #{command.parameter_help(0)} and redisplay" }

      command.undoable = false

      command.as_action do |args|
        set_status(view: args[:view].to_i)
        @config_form_editor.refresh_form if @config_form_editor
        render_previews
      end
    end


    @commands.add_command(:loglevel) do |c|
      c.undoable = false
      c.set_help { "set log level to #{c.parameter_help(0)}" }
      c.add_parameter(:level, :string) do |parameter|
        parameter.set_default { "warning" }
        parameter.set_help { "error | warning | info | debug" }
      end
      c.as_action do |args|
        $log.loglevel=args[:level]
        set_status(loglevel: $log.loglevel)
      end
    end

    @commands.add_command(:autorefresh) do |c|
      c.undoable = false
      c.set_help { "turnon autorefresh" }
      values = {on: :on, off: :off, remote: :remote}
      c.add_parameter(:value, :string) do |parameter|
        parameter.set_default { :true }
        parameter.set_help { "#{values.keys.join(" | ")}" }
      end
      c.as_action do |args|

        result = values[args[:value]]
        if result
          set_status(autorefresh: result)
        else
          $log.error("wrong parameter #{args[:value]}, #{c.parameter_help(0)}")
        end
      end
    end

    @commands.add_command(:undo) do |c|
      c.undoable = false
      c.set_help { "undo last command" }
      c.as_action do |a|
        @commands.undo
      end
    end

    @commands.add_command(:redo) do |c|
      c.undoable = false
      c.set_help { "redo last command" }
      c.as_action do |a|
        @commands.redo
      end
    end

    @commands.add_command(:history) do |c|
      c.undoable = false
      c.set_help { "show history" }
      c.as_action do |a|
        history = @commands.history.map { |c| "#{c.first}: #{c[1].name}(#{c.last})" }
        $log.message("<pre>#{history.join("\n")}</pre>")
      end
    end


    @commands.add_command(:showundo) do |c|
      c.undoable = false
      c.set_help { "show undo stack" }
      c.as_action do |a|
        history = @commands.undostack.map { |c| "#{c.first}: #{c[1].name}(#{c.last})" }
        $log.message("<pre>#{history.join("\n")}</pre>")
      end
    end

    @commands.add_command(:showredo) do |c|
      c.undoable = false
      c.set_help { "show redo stack" }
      c.as_action do |a|
        history = @commands.redostack.map { |c| "#{c.first}: #{c[1].name}(#{c.last})" }
        $log.message("<pre>#{history.join("\n")}</pre>")
      end
    end
  end

  def __ic_02_play_commands
    @commands.add_command(:p) do |c|
      c.undoable = false
      c.set_help { "play song #{c.parameter_help(0)}" }
      c.add_parameter(:range, :string) do |parameter|
        parameter.set_default { "ff" }
        parameter.set_help { "r(all | ff | sel): range to play" }
      end

      c.as_action do |argument|
        case argument[:range]
          when "auto"
            play_abc(:auto)

          when "sel"
            play_abc(:selection)

          when "ff"
            play_abc(:selection_ff)

          when "all"
            play_abc
          else
            $log.error("wrong range to play")
        end
      end
    end

    @commands.add_command(:stop) do |c|
      c.undoable = false
      c.set_help { "stop playing" }
      c.as_action do |a|
        stop_play_abc
      end
    end

    @commands.add_command(:render) do |c|
      c.undoable = false
      c.set_help { "refresh" }
      c.as_action do |a|
        render_previews
      end
    end

  end

  def __ic_03_create_commands

    @commands.add_command(:c) do |c|
      c.set_help { "create song #{c.parameter_help(0)} #{c.parameter_help(1)}" }
      c.add_parameter(:id, :string) do |parameter|
        parameter.set_help { "value for X: line, a unique id" }
      end

      c.add_parameter(:title, :string) do |parameter|
        parameter.set_default { "untitled" }
        parameter.set_help { "Title of the song" }
      end

      c.as_action do |args|

        song_id    = args[:id]
        song_title = args[:title]
        filename   = song_title.strip.gsub(/[^a-zA-Z0-9\-\_]/, "_")
        raise "no id specified" unless song_id
        raise "no title specified" unless song_title

        ## todo use erb for this
        template      = %Q{X:#{song_id}
F:#{song_id}_#{filename}
T:#{song_title}
C:
S:
M:4/4
L:1/4
Q:1/4=120
K:C
%%score 1 2
V:1 clef=treble-8 name="Sopran" snm="S"
C
V:2 clef=treble-8  name="Alt" snm="A"
C,

%%%%zupfnoter.config

{
  "produce": [1],
  "$schema"  : "https://zupfnoter.weichel21.de/schema/zupfnoter-config_1.0.json",
  "$version" : "#{VERSION}"

}
}
        args[:oldval] = @editor.get_text
        @editor.set_text(template)
        set_status(music_model: "new")
        render_previews
      end

      c.as_inverse do |args|
        @editor.set_text(args[:oldval])
      end
    end


    @commands.add_command(:drop) do |command|
      command.set_help { "Handle a dropped _abc" }

      command.as_action do |args|
        args[:oldval] = @editor.get_text
        @editor.set_text(@dropped_abc)
        render_previews
      end

      command.as_inverse do |args|
        # todo maintain editor status
        @editor.set_text(args[:oldval])
      end
    end

    @commands.add_command(:conf) do |command|
      command.undoable = false

      command.add_parameter(:key, :string) do |parameter|
        parameter.set_help { "parameter key" }
      end

      command.add_parameter(:value, :boolean) do |parameter|
        parameter.set_help { "parameter value (true | false" }
      end


      command.set_help { "set configuration parameter true/false" }

      command.as_action do |args|
        value = {'true' => true, 'false' => false}[args[:value]]

        raise "invalid key #{args[:key]}" unless $conf.keys.include?(args[:key])
        raise "value must be true or false" if value.nil?
        $conf[args[:key]] = value

        nil
      end

      command.as_inverse do |args|
        $conf.pop # todo: this is a bit risky
      end
    end

    @commands.add_command(:stdnotes) do |command|
      command.undoable = false

      command.set_help { "configure with template from localstore" }

      command.as_action do |args|
        handle_command("addconf standardnotes")
      end
    end


    @commands.add_command(:setstdnotes) do |command|
      command.undoable = false

      command.set_help { "configure stdnotes in localstore" }

      command.as_action do |args|
        template = @editor.get_config_part_value('extract.0').to_json
        `localStorage.setItem('standardnotes', #{template})`
        nil
      end
    end


    @commands.add_command(:addconf) do |command|
      command.undoable = false

      command.add_parameter(:key, :string) do |parameter|
        parameter.set_help { "parameter key" }
      end

      command.set_help { "add configuration parameter" }

      command.as_action do |args|

        values = {
            'title'            => lambda { {key: "extract.#{@systemstatus[:view]}.title", value: "ENTER_TITLE_EXTRACT_#{@systemstatus[:view]}"} },
            'voices'           => lambda { {key: "extract.#{@systemstatus[:view]}.voices", value: $conf['extract.0.voices']} },
            'flowlines'        => lambda { {key: "extract.#{@systemstatus[:view]}.flowlines", value: $conf['extract.0.flowlines']} },
            'layoutlines'      => lambda { {key: "extract.#{@systemstatus[:view]}.layoutlines", value: $conf['extract.0.layoutlines']} },
            'jumplines'        => lambda { {key: "extract.#{@systemstatus[:view]}.jumplines", value: $conf['extract.0.jumplines']} },
            'repeatsigns.full' => lambda { {key: "extract.#{@systemstatus[:view]}.repeatsigns", value: $conf['extract.0.repeatsigns']} },
            'repeatsigns'      => lambda { {key: "extract.#{@systemstatus[:view]}.repeatsigns.voices", value: $conf['extract.0.repeatsigns.voices']} },
            'synchlines'       => lambda { {key: "extract.#{@systemstatus[:view]}.synchlines", value: $conf['extract.0.synchlines']} },
            'legend'           => lambda { {key: "extract.#{@systemstatus[:view]}.legend", value: $conf['extract.0.legend']} },
            'notes'            => lambda { {key: "extract.#{@systemstatus[:view]}.notes.x", value: $conf['templates.notes']} },
            'lyrics'           => lambda { {key: "extract.#{@systemstatus[:view]}.lyrics.x", value: $conf['templates.lyrics']} },
            'nonflowrest'      => lambda { {key: "extract.#{@systemstatus[:view]}.nonflowrest", value: $conf['extract.0.nonflowrest']} },
            'startpos'         => lambda { {key: "extract.#{@systemstatus[:view]}.startpos", value: $conf['extract.0.startpos']} },
            'subflowlines'     => lambda { {key: "extract.#{@systemstatus[:view]}.subflowlines", value: $conf['extract.0.subflowlines']} },
            'produce'          => lambda { {key: "produce", value: $conf['produce']} },
            'annotations'      => lambda { {key: "annotations.x", value: $conf['templates.annotations']} },
            'layout'           => lambda { {key:   "extract.#{@systemstatus[:view]}.layout",
                                            value: $conf['extract.0.layout']} }, # radii of the largest Rest Glyph} },
            'printer'          => lambda { {key:   "extract.#{@systemstatus[:view]}.printer",
                                            value: $conf['extract.0.printer']} }, # radii of the largest Rest Glyph} },
            'countnotes'       => lambda { {key: "extract.#{@systemstatus[:view]}.countnotes", value: $conf['extract.0.countnotes']} },

            'barnumbers'       => lambda { {key:   "extract.#{@systemstatus[:view]}.barnumbers",
                                            value: {
                                                voices: [],
                                                pos:    [6, -4]
                                            }} },
            'barnumbers.full'  => lambda { {key: "extract.#{@systemstatus[:view]}.barnumbers", value: $conf['extract.0.barnumbers']} },

            'stringnames.full' => lambda { {key: "extract.#{@systemstatus[:view]}.stringnames", value: $conf['extract.0.stringnames']} },
            'stringnames'      => lambda { {key: "extract.#{@systemstatus[:view]}.stringnames.vpos", value: $conf['extract.0.stringnames.vpos']} },

            'restpos_1.3'      => lambda { {key: "restposition", value: {default: :next, repeatstart: :next, repeatend: :previous}} },
            'standardnotes'    => lambda { {key: "extract.#{@systemstatus[:view]}", value: JSON.parse(`localStorage.getItem('standardnotes')`)} },
            'x1'               => lambda { {key: "xx", value: $conf[]} },
            'xx'               => lambda { {key: "extract.#{@systemstatus[:view]}", value: $conf['extract.0']} },
            'hugo'             => lambda { {key: "extract.#{@systemstatus[:view]}",
                                            value:
                                                 [:title, :voices, :flowlines, :synchlines, :jumplines].inject({}) do |r, k|
                                                   r[k] = $conf["extract.#{@systemstatus[:view]}.#{k}"]
                                                   r
                                                 end} }
        }

        # create the commands for presets

        $conf['presets.notes'].each do |key, preset_value|
          entry = $conf["presets.notes.#{key}"]
          to_key = entry[:key] || key
          value = entry[:value]
          values["preset.notes.#{key}"] = lambda { {key: "extract.#{@systemstatus[:view]}.notes.#{to_key}", value: value, method: :patch} }
        end

        $conf['presets.layout'].each do |key, preset_value|
          values["preset.layout.#{key}"] = lambda { {key: "extract.#{@systemstatus[:view]}.layout", value: $conf["presets.layout.#{key}"], method: :preset} }
        end

        $conf['presets.printer'].each do |key, preset_value|
          values["preset.printer.#{key}"] = lambda { {key: "extract.#{@systemstatus[:view]}", value: $conf["presets.printer.#{key}"], method: :preset} }
        end

        # here we handle the menu stuff
        value = values[args[:key]]
        if value

          value = value.call

          localconf              = Confstack.new(false)
          localconf.strict       = false
          localconf[value[:key]] = value[:value]
          keys_from_value        = localconf.keys

          config_from_editor = get_config_from_editor
          localconf.push(config_from_editor) unless value[:method] == :preset

          patchvalue = localconf[value[:key]]

          the_key = value[:key]
          # this computes the next key number
          if the_key.end_with?('.x')
            parent_key = the_key.split('.')[0..-2].join(".")
            next_free  = localconf[parent_key].keys.map { |k| k.split('.').last.to_i }.sort.last + 1
            the_key    = %Q{#{parent_key}.#{next_free}}
          end

          @editor.patch_config_part(the_key, patchvalue)
          @config_form_editor.refresh_form if @config_form_editor
        else
          raise "unknown configuration parameter #{args[:key]}"
          nil
        end
      end
    end


    @commands.add_command(:editconf) do |command|

      def expand_extract_keys(keys)
        keys.map { |k| "extract.#{@systemstatus[:view]}.#{k}" }
      end

      command.undoable = false

      command.add_parameter(:set, :string) do |parameter|
        parameter.set_help { "one of the editable keys" } #"#{sets.keys.to_s}" }
      end

      command.set_help { "edit configuration parameters (#{command.parameter_help(0)})" }

      command.as_action do |args|
        $log.timestamp("editconf #{args[:set]}  #{__FILE__} #{__LINE__}")

        sets = {
            basic_settings:        {keys: [:produce] + expand_extract_keys([:title, :filenamepart, :voices, :flowlines, :synchlines, :jumplines, :layoutlines,
                                                                            'repeatsigns.voices', 'barnumbers.voices','barnumbers.autopos', 'countnotes.voices','countnotes.autopos',
                                                                            'printer.show_border', 'stringnames.vpos',
                                                                            :startpos,
                                                                           ]) + [:restposition]},
            barnumbers_countnotes: {keys: expand_extract_keys([:barnumbers, :countnotes])},

            annotations:           {keys: [:annotations], newentry_handler: lambda { handle_command("addconf annotations") }},
            notes:                 {keys: expand_extract_keys([:notes]), newentry_handler: lambda { handle_command("addconf notes") }, quicksetting_commands: _get_quicksetting_commands('notes')},
            lyrics:                {keys: expand_extract_keys([:lyrics]), newentry_handler: lambda { handle_command("addconf lyrics") }},
            layout:                {keys: expand_extract_keys([:layout, 'layout.limit_a3']), quicksetting_commands: _get_quicksetting_commands('layout')},
            printer:               {keys: expand_extract_keys([:printer, 'layout.limit_a3']), quicksetting_commands: _get_quicksetting_commands('printer')},
            stringnames:           {keys: expand_extract_keys([:stringnames])},
            extract0:              {keys: ['extract.0']},
            extract_current:       {keys: expand_extract_keys($conf.keys.select { |k| k.start_with?('extract.0.') }.map { |k| k.split('extract.0.').last })},
            xx:                    {keys: ['xx']}
        }

        a = sets[args[:set]]
        if a
          editable_keys         = a[:keys]
          newentry_handler      = a[:newentry_handler]
          quicksetting_commands = a[:quicksetting_commands] || []
        else # use the argument as key if there is no set.
          quicksetting_commands = []
          editable_keys         = [args[:set]]
        end


        # this handler yields three value sets
        # the current value

        get_configvalues = lambda do
          $log.timestamp("1 #{__FILE__} #{__LINE__}")


          $log.timestamp("5  #{__FILE__} #{__LINE__}")


          editor_conf        = Confstack.new(false)
          editor_conf.strict = false
          editor_conf.push(get_config_from_editor)

          effective_values = Confstack.new(false)
          editable_values = Confstack.new(false)

          editable_keys.each do |k|
            editable_values[k] = editor_conf[k]
            zerokey = k.gsub(/extract\.[^\.]+/, 'extract.0')
            value = editable_values[k]
            value = $conf[k] if value.nil?
            value = editor_conf[zerokey] if value.nil?
            value = $conf[zerokey] if value.nil?
            effective_values[k] = value
          end

          $log.timestamp("6  #{__FILE__} #{__LINE__}")

          {current: editable_values.get, effective: effective_values.get, default: effective_values.get}
        end

        refresh_editor = lambda do
          handle_command("editconf #{args[:set]}")
        end

        editor_title        = %Q{Exract #{@systemstatus[:view]}: #{args[:set]}}
        editorparams        = {
            title:                 editor_title,
            editor:                @editor,
            value_handler:         get_configvalues,
            refresh_handler:       refresh_editor,
            newentry_handler:      newentry_handler,
            quicksetting_commands: quicksetting_commands,
            controller:            self
        }
        #config_form_editor = ConfstackEditor.new(editor_title, @editor, get_configvalues, refresh_editor)
        @config_form_editor = ConfstackEditor.new(editorparams)
        @config_form_editor.generate_form

        nil
      end

      command.as_inverse do |args|
        $conf.pop # todo: this is a bit risky
      end
    end

    @commands.add_command(:editsnippet) do |command|
      command.undoable = false
      command.set_help { "edit current snippet" }

      command.as_action do |args|
        sel = @editor.get_selection_info
        SnippetEditor.new.setup(sel[:token][:type], sel[:token][:value]) do |value|
          @editor.patch_token(sel[:token][:type], 0, value)
        end
        nil
      end
    end

    @commands.add_command(:addsnippet) do |command|
      command.undoable = false
      command.set_help { "edit current snippet" }

      command.add_parameter(:token, :string) do |parameter|
        parameter.set_help { "parameter key" }
      end

      command.as_action do |args|
        sel = @editor.get_selection_info
        SnippetEditor.new.setup("zupfnoter.editable.#{args[:token]}", nil) do |value|
          @editor.patch_token(sel[:token][:type], 0, value)
        end
        nil
      end
    end


    @commands.add_command(:cconf) do |command|
      command.undoable = false

      command.add_parameter(:key, :string) do |parameter|
        parameter.set_help { "parameter key" }
      end

      command.add_parameter(:value, :string) do |parameter|
        parameter.set_help { "parameter value as JSON" }
      end


      command.set_help { "set configuration parameter" }

      command.as_action do |args|
        value = JSON.parse(args[:value])

        @editor.patch_config_part(args[:key], value)

        nil
      end

      command.as_inverse do |args|
        $conf.pop # todo: this is a bit risky
      end
    end


  end

  def get_conf_value_from_editor_for_current_view(key)

    localconf       = Confstack.new
    localconf.strict=false

    config_from_editor = get_config_from_editor
    localconf.push(config_from_editor)

    value = localconf[key]

    value
  end

  # this yields an array of addconf-arguments
  # used to populate a preset menu
  def _get_quicksetting_commands(preset_domain)
    $conf["presets.#{preset_domain}"].map do |k, v|
      %Q{preset.#{preset_domain}.#{k}}
    end
  end

  def __ic_04_localstore_commands
    @commands.add_command(:lsave) do |c|
      c.undoable = false

      c.set_help do
        "save to localstore";
      end

      c.as_action do
        abc_code = @editor.get_text
        metadata = @abc_transformer.get_metadata(abc_code)
        filename = "#{metadata[:X]}_#{metadata[:T]}"
        @songbook.update(metadata[:X], abc_code, metadata[:T], true)
        set_status(music_model: "saved to localstore")
        $log.message("saved to '#{filename}'")
      end
    end

    @commands.add_command(:lls) do |c|
      c.undoable = false
      c.set_help { "list files in localstore" }
      c.as_action do |a|
        # list the songbook
        $log.message("<pre>" + @songbook.list.map { |k, v| "#{k}_#{v}" }.join("\n") + "</pre>")
      end
    end

    @commands.add_command(:lopen) do |c|
      c.undoable = true
      c.add_parameter(:id, :string) { |parameter|
        parameter.set_help { "id of the song to be loaded" }
      }

      c.set_help { "open song from local store  #{c.parameter_help(0)}" }

      c.as_action do |args|
        # retrieve a song
        if args[:id]
          payload = @songbook.retrieve(args[:id])
          if payload
            args[:oldval] = @editor.get_text
            @editor.set_text(payload)
          else
            $log.error("song #{command_tokens.last} not found")
          end
        else
          $log.error("plase add a song number")
        end
      end

      c.as_inverse do |args|
        @editor.set_text(args[:oldval])
      end
    end
  end

  def __ic_05_dropbox_commands
    @commands.add_command(:dlogin) do |command|
      command.add_parameter(:scope, :string) do |parameter|
        parameter.set_default { @systemstatus[:dropboxapp] || 'full' }
        parameter.set_help { "(app | full) app: app only | full: full dropbox" }
      end

      command.add_parameter(:path, :string) do |parameter|
        parameter.set_default { @systemstatus[:dropboxpath] || "/" }
        parameter.set_help { "path to set in dropbox" }
      end

      command.set_help { "dropbox login for #{command.parameter_help(0)}" }

      command.as_action do |args|

        path = args[:path]
        path += '/' unless path.end_with? '/'

        case args[:scope]
          when "full"
            @dropboxclient          = Opal::DropboxJs::Client.new('us2s6tq6bubk6xh')
            @dropboxclient.app_name = "DrBx"
            @dropboxclient.app_id   = "full"
            @dropboxpath            = path

          when "app"
            @dropboxclient          = Opal::DropboxJs::Client.new('xr3zna7wrp75zax')
            @dropboxclient.app_name = "App"
            @dropboxclient.app_id   = "app"
            @dropboxpath            = path

          else
            $log.error("select app | full")
        end


        # notes
        # the login approach in dropbox redirects to login-pages from dropbix which eventually
        # return to zupfnoter with an access token.
        # Zupfnoter then finalizes the login by invoking zndropboxlogincmd at the end of Controller.initialize
        # therefore we need to store it here
        #
        set_status({zndropboxlogincmd: %Q{dlogin #{args[:scope]} "#{args[:path]}"}})

        # now do the authentification
        @dropboxclient.authenticate().then do
          set_status({zndropboxlogincmd: nil}) # nos login was sucessful, therefore we do not need this command anymore -
          set_status_dropbox_status
          $log.message("logged in at dropbox with #{args[:scope]} access")
        end.fail do |err|
          _report_error_from_promise err
        end
      end
      command.as_inverse do |args|
        set_status(dropbox: I18n.t("logged out"))

        $log.message("logged out from dropbox")
        @dropboxclient = Opal::DropboxJs::NilClient.new
      end
    end

    @commands.add_command(:dls) do |command|
      command.undoable = false

      command.add_parameter(:path, :string) do |parameter|
        parameter.set_default { @dropboxpath || "/" }
        parameter.set_help { "path in dropbox #{@dropboxclient.app_name}" }
      end

      command.set_help { "list files in #{command.parameter_help(0)}" } # todo factor out to comman class

      command.as_action do |args|
        rootpath = args[:path]
        $log.message("#{@dropboxclient.app_name}: #{args[:path]}:")

        @dropboxclient.authenticate().then do
          @dropboxclient.read_dir(rootpath)
        end.then do |entries|
          $log.message("<pre>" + entries.select { |entry| entry =~ /\.abc$/ }.join("\n").to_s + "</pre>")
        end
      end
    end

    @commands.add_command(:dcd) do |command|
      command.add_parameter(:path, :string) do |parameter|
        parameter.set_default { @dropboxpath }
        parameter.set_help { "path in dropbox #{@dropboxclient.app_name}" }
      end

      command.set_help { "dropbox change dir to #{command.parameter_help(0)}" }

      command.as_action do |args|
        rootpath      = args[:path]
        args[:oldval] = @dropboxpath
        @dropboxpath  = rootpath

        set_status_dropbox_status
        $log.message("dropbox path changed to #{@dropboxpath}")
      end

      command.as_inverse do |args|
        @dropboxpath = args[:oldval]
        set_status_dropbox_status
        $log.message("dropbox path changed back to #{@dropboxpath}")
      end
    end

    @commands.add_command(:dpwd) do |command|
      command.undoable = false

      command.set_help { "show drobox path" }

      command.as_action do |args|
        $log.message("#{@dropboxclient.app_name}: #{@dropboxpath}")
      end
    end


    @commands.add_command(:dchoose) do |command|
      command.undoable = false

      command.set_help { "choose File from Dropbox" }

      command.as_action do |args|
        @dropboxclient.authenticate
        @dropboxclient.choose_file({}).then do |files|
          chosenfile = files.first[:link]
          # Dropbox returns either https://dl.dropboxusercontent.com/1/view/offjt8qk520cywc/3010_counthints.abc
          # or https://dl.dropboxusercontent.com/1/view/offjt8qk520cywc/3010_counthints.abc
          fileparts  = chosenfile.match(/.*\/view\/[^\/]*\/(.+\/)?(.*)/).to_a
          path       = "/#{fileparts[1]}"
          filename   = `decodeURIComponent(#{fileparts.last})`

          newpath = "#{path}"
          handle_command("dlogin full #{path}")
          $log.message("found #{path}#{filename}")
          handle_command(%Q{dopenfn "#{filename}"})
          $log.message("opened #{path}#{filename}")
        end.fail do |message|
          $log.error message
        end
      end
    end


    @commands.add_command(:download_abc) do |command|
      command.undoable = false ## todo make this undoable

      command.set_help { "download as abc" }

      command.as_action do |args|
        abc_code = @editor.get_text
        metadata = @abc_transformer.get_metadata(abc_code)
        filebase = metadata[:F].first rescue nil
        if filebase
          filebase = filebase.split("\n").first
        else
          `w2alert("Filename not specified in song! Please add an F:<filename> instruction to your abc", "Error")`
          raise "Filename not specified in song add an F:<filename> instruction" ## "#{metadata[:X]}_#{metadata[:T]}"
        end

        %x{
          var element = document.createElement('a');
          element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(#{abc_code}));
          element.setAttribute('download', #{filebase + ".abc"});

          element.style.display = 'none';
          document.body.appendChild(element);

          element.click();

          document.body.removeChild(element);
        }

      end
    end


    @commands.add_command(:dsave) do |command|
      command.add_parameter(:path, :string) do |parameter|
        parameter.set_default { @dropboxpath }
        parameter.set_help { "path to save in #{@dropboxclient.app_name}" }
      end

      command.undoable = false ## todo make this undoable

      command.set_help { "save to dropbox {#{command.parameter_help(0)}}" }

      command.as_action do |args|

        unless @systemstatus[:mode] == :work
          message = "Cannot save in  #{@systemstatus[:mode]} mode"
          alert message
          raise message
        end

        abc_code = @editor.get_text
        metadata = @abc_transformer.get_metadata(abc_code)

        filebase = metadata[:F]
        if filebase
          filebase = filebase.first.split("\n").first
        else
          raise "Filename not specified in song add an F: instruction" ## "#{metadata[:X]}_#{metadata[:T]}"
        end

        layout_harpnotes # todo: this uses a side-effect to get the @music_model populated
        render_previews

        print_variants = @music_model.harpnote_options[:print]

        rootpath = args[:path]

        save_promises=[]
        @dropboxclient.authenticate().then do
          save_promises = [@dropboxclient.write_file("#{rootpath}#{filebase}.abc", @editor.get_text)]
          save_promises.push [@dropboxclient.write_file("#{rootpath}#{filebase}.html", @tune_preview_printer.get_html)]
          pdfs = {}
          print_variants.map do |print_variant|
            index                                                                 = print_variant[:view_id]
            pdfs["#{rootpath}#{filebase}_#{print_variant[:filenamepart]}_a3.pdf"] = render_a3(index).output(:blob)
            pdfs["#{rootpath}#{filebase}_#{print_variant[:filenamepart]}_a4.pdf"] = render_a4(index).output(:blob)
            nil
          end

          pdfs.each do |name, pdfdata|
            save_promises.push(@dropboxclient.write_file(name, pdfdata))
          end
        end
        Promise.when(*save_promises).then do
          set_status(music_model: I18n.t("saved to dropbox"))
          $log.message("all files saved")
        end.fail do |err|
          _report_error_from_promise(err)
        end
      end
    end

    @commands.add_command(:dopen) do |command|

      command.add_parameter(:fileid, :string, "file id")
      command.add_parameter(:path, :string) do |p|
        p.set_default { @dropboxpath }
        p.set_help { "path to save in #{@dropboxclient.app_name}" }
      end

      command.set_help { "read file with #{command.parameter_help(0)}, from dropbox #{command.parameter_help(1)}" }

      command.as_action do |args|
        args[:oldval] = @editor.get_text
        fileid        = args[:fileid]
        fileidfound   = nil
        rootpath      = args[:path] # command_tokens[2] || @dropboxpath || "/"
        $log.message("get from Dropbox path #{rootpath}#{fileid}_ ...:")

        @dropboxclient.authenticate().then do |error, data|
          @dropboxclient.read_dir(rootpath)
        end.then do |entries|
          $log.debug("#{entries} (#{__FILE__} #{__LINE__})")
          fileidfound = entries.select { |entry| entry =~ /^#{fileid}_.*\.abc$/ }
          unless fileidfound
            result = Promise.new.reject(%Q{#{I18n.t("There is no file with this id")} in #{rootpath}})
          else
            unless fileidfound.count == 1
              result = Promise.new.reject(%Q{#{I18n.t("Ambiguous file number")}: #{fileid} in #{rootpath}:\n #{fileidfound.join("\n ")}}) unless fileidfound.count == 1
            else
              fileidfound = fileidfound.first
              result      = @dropboxclient.read_file("#{rootpath}#{fileidfound}")
            end
          end
          result
        end.then do |abc_text|
          $log.debug "loaded #{fileidfound} (#{__FILE__} #{__LINE__})"
          filebase = fileidfound.split(".abc")[0 .. -1].join(".abc")
          abc_text = @abc_transformer.add_metadata(abc_text, F: filebase)

          @editor.set_text(abc_text)
          set_status(music_model: "loaded")
          handle_command("render")

        end.fail do |err|
          _report_error_from_promise (%Q{could not load file with ID #{fileid}: #{err}})
        end
      end

      command.as_inverse do |args|
        # todo maintain editor status
        @editor.set_text(args[:oldval])
      end
    end


    @commands.add_command(:dopenfn) do |command|

      command.add_parameter(:fileid, :string, "file id")
      command.add_parameter(:path, :string) do |p|
        p.set_default { @dropboxpath }
        p.set_help { "path to save in #{@dropboxclient.app_name}" }
      end

      command.set_help { "read file with #{command.parameter_help(0)}, from dropbox #{command.parameter_help(1)}" }

      command.as_action do |args|
        args[:oldval] = @editor.get_text
        fileid        = args[:fileid]
        rootpath      = args[:path] # command_tokens[2] || @dropboxpath || "/"
        filename      = "#{rootpath}#{fileid}"
        $log.message("get from Dropbox path #{rootpath}#{fileid}_ ...:")

        @dropboxclient.authenticate().then do |error, data|
          @dropboxclient.read_file(filename)
        end.then do |abc_text|
          $log.debug "loaded #{fileid} (#{__FILE__} #{__LINE__})"
          filebase = fileid.split(".abc")[0 .. -1].join(".abc")
          abc_text = @abc_transformer.add_metadata(abc_text, F: filebase)

          @editor.set_text(abc_text)
          set_status(music_model: "loaded")
          handle_command("render")

        end.fail do |err|
          _report_error_from_promise %Q{#{I18n.t('could not open file')}: #{err} : "#{filename}"}
          nil
        end
      end

      command.as_inverse do |args|
        # todo maintain editor status
        @editor.set_text(args[:oldval])
      end
    end

  end
end

