class Controller
  private

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

        song_id = args[:id]
        song_title = args[:title]
        filename = song_title.gsub(/[^a-zA-Z0-9\-\_]/, "_")
        raise "no id specified" unless song_id
        raise "no title specified" unless song_title

        ## todo use erb for this
        template = %Q{X:#{song_id}
F:#{song_id}_#{filename}
T:#{song_title}
C:
S:
M:4/4
L:1/4
Q:1/4=120
K:C
%%score T1 T2  B1 B2
V:T1 clef=treble-8 name="Sopran" snm="S"
C
V:T2 clef=treble-8  name="Alt" snm="A"
C,

%%%%hn.config

{
  "produce": ["1", "2"]
}
}
        args[:oldval] = @editor.get_text
        @editor.set_text(template)
        set_status(music_model: "new")
      end

      c.as_inverse do |args|
        @editor.set_text(args[:oldval])
      end
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
        parameter.set_default { "app" }
        parameter.set_help { "(app | full) app: app only | full: full dropbox" }
      end

      command.add_parameter(:path, :string) do |parameter|
        parameter.set_default { "/" }
        parameter.set_help { "path to set in dropbox" }
      end


      command.set_help { "dropbox login for #{command.parameter_help(0)}" }

      command.as_action do |args|
        case args[:scope]
          when "full"
            @dropboxclient = Opal::DropboxJs::Client.new('us2s6tq6bubk6xh')
            @dropboxclient.app_name = "full Dropbox"
            @dropboxpath = args[:path]

          when "app"
            @dropboxclient = Opal::DropboxJs::Client.new('xr3zna7wrp75zax')
            @dropboxclient.app_name = "App folder only"
            @dropboxpath = args[:path]

          else
            $log.error("select app | full")
        end

        @dropboxclient.authenticate().then do
          set_status(dropbox: "#{@dropboxclient.app_name}: #{@dropboxpath}")
          $log.message("logged in at dropbox with #{args[:scope]} access")
        end
      end
      command.as_inverse do |args|
        set_status(dropbox: "logged out")

        $log.message("logged out from dropbox")
        @dropboxclient = nil
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
        rootpath = args[:path]
        args[:oldval] = @dropboxpath
        @dropboxpath = rootpath

        set_status(dropbox: "#{@dropboxclient.app_name}: #{@dropboxpath}")
        $log.message("dropbox path changed to #{@dropboxpath}")
      end

      command.as_inverse do |args|
        @dropboxpath = args[:oldval]
        set_status(dropbox: "#{@dropboxclient.app_name}: #{@dropboxpath}")
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

    @commands.add_command(:dsave) do |command|
      command.add_parameter(:path, :string) do |parameter|
        parameter.set_default { @dropboxpath }
        parameter.set_help { "path to save in #{@dropboxclient.app_name}" }
      end

      command.undoable = false ## todo make this undoable

      command.set_help { "save to dropbox {#{command.parameter_help(0)}}" }

      command.as_action do |args|
        abc_code = @editor.get_text
        metadata = @abc_transformer.get_metadata(abc_code)
        filebase = metadata[:F]
        $log.debug("#{metadata.to_s} (#{__FILE__} #{__LINE__})")
        if filebase
          filebase = filebase.split("\n").first
        else
          raise "Filename not specified in song add an F: instruction" ## "#{metadata[:X]}_#{metadata[:T]}"
        end

        layout_harpnotes # todo: this uses a side-effect to get the @music_model populated
        render_previews

        print_variants = @music_model.harpnote_options[:print]

        rootpath = args[:path]

        @dropboxclient.authenticate().then do

          save_promises = [@dropboxclient.write_file("#{rootpath}#{filebase}.abc", @editor.get_text)]
          pdfs = {}
          print_variants.map do |print_variant|
            index = print_variant[:view_id]
            filename = print_variant[:title].gsub(/[^a-zA-Z0-9\-\_]/, "_")
            pdfs["#{rootpath}#{filebase}_#{print_variant[:title]}_a3.pdf"] = render_a3(index).output(:blob)
            pdfs["#{rootpath}#{filebase}_#{print_variant[:title]}_a4.pdf"] = render_a4(index).output(:blob)
          end

          pdfs.each do |name, pdfdata|
            save_promises.push(@dropboxclient.write_file(name, pdfdata))
          end
          save_promises.push(@dropboxclient.write_file("#{rootpath}#{filebase}.abc", @editor.get_text))

          Promise.when(save_promises)
        end.then do
          set_status(music_model: "saved to dropbox")
          $log.message("all files saved")
        end.fail do |err|
          $log.error("there was an error saving files #{err}")
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
        fileid = args[:fileid]
        rootpath = args[:path] # command_tokens[2] || @dropboxpath || "/"
        $log.message("get from Dropbox path #{rootpath}#{fileid}_ ...:")

        @dropboxclient.authenticate().then do |error, data|
          @dropboxclient.read_dir(rootpath)
        end.then do |entries|
          $log.debug("#{entries} (#{__FILE__} #{__LINE__})")
          fileid = entries.select { |entry| entry =~ /#{fileid}_.*\.abc$/ }.first
          @dropboxclient.read_file("#{rootpath}#{fileid}")
        end.then do |abc_text|
          $log.debug "loaded #{fileid} (#{__FILE__} #{__LINE__})"
          filebase = fileid.split(".abc")[0 .. -1].join(".abc")
          abc_text = @abc_transformer.add_metadata(abc_text, F: filebase)

          @editor.set_text(abc_text)
          set_status(music_model: "loaded")
        end.fail do |err|
          $log.error("could not load file #{err}")
        end
      end

      command.as_inverse do |args|
        # todo maintain editor status
        @editor.set_text(args[:oldval])
      end

    end


  end
end

