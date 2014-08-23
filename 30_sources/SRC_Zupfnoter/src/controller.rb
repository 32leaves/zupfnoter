# This is a wrapper class for local store

class LocalStore

  def initialize(name)
    @name = name
    load_dir

    unless @directory
      @directory = {}
      save_dir
    end
  end


  def create(key, item, title = nil)
    if @directory[key]
      $log.warning("local storage: key '#{key}' already exists")
    else
      update(key, item, title, true)
    end
  end


  def update(key, item, title = nil, create = false)
    envelope = {p: item, title: title}.to_json
    if @directory[key] || create
      `localStorage.setItem(self.$mangle_key(key), envelope)`
      @directory[key] = title
      save_dir
    else
      $log.warning("local storage update: key '#{key}' does not exist")
    end
  end

  def retrieve(key)
    envelope = JSON.parse(`localStorage.getItem(self.$mangle_key(key))`)
    result = envelope[:p] if envelope
    result
  end

  def delete(key)
    if @directory[key]
      $log.warn("local storage: key '#{key}' does not exist")
    else
      `localStorage.deleteItem(self.$mangle_key(key))`
      @directory[key] = nil
      save_dir
    end
  end

  def list
    @directory.clone
  end

  private


  def mangle_key(key)
    "#{@name}.#{key}"
  end

  def load_dir
    dirkey = "#{@name}__dir"
    @directory = JSON.parse(`localStorage.getItem(dirkey)`)
  end

  def save_dir
    dir_json = @directory.to_json
    dirkey = "#{@name}__dir"
    `localStorage.setItem(dirkey, dir_json)`
  end

end


class Controller

  attr :editor, :harpnote_preview_printer, :tune_preview_printer

  def initialize
    $log = ConsoleLogger.new("consoleEntries")
    @editor = Harpnotes::TextPane.new("abcEditor")
    @harpnote_player = Harpnotes::Music::HarpnotePlayer.new()
    @songbook = LocalStore.new("songbook")
    @abc_transformer = Harpnotes::Input::ABCToHarpnotes.new


    @commands = CommandController::CommandStack.new
    $log.debug self.methods
    self.methods.select { |n| n =~ /__ic.*/ }.each { |m| send(m) }

    setup_ui
    setup_ui_listener
    load_from_loacalstorage

  end


  # this handles a command
  # todo: this is a temporary hack until we have a proper ui
  def handle_command(command)

    begin
      @commands.run_string(command)
    rescue Exception => e
      $log.error(e.message)
    end
    return

    command_tokens = command.split(" ")
    case command_tokens.first

      # save current song
      # todo check the title

      when "s"
        abc_code = @editor.get_text
        metadata = @abc_transformer.get_metadata(abc_code)
        @songbook.update(metadata[:X], abc_code, metadata[:T])
        $log.info("saved #{metadata[:X]}, '#{metadata[:T]}'")

      when "lw"
        $log.debug ("listing webdav")
        Browser.HTTP.get("http://www.weichel21.de/months.js").then do |response|
          $log.debug "returned #{response.status_code}"
          $log.debug response.body

        end

      when "logindropfull"
        @dropboxclient = Opal::DropboxJs::Client.new('14ezuf8dtur5uoz') # ol56zaikdq4kxjx
        #@dropboxclient = Opal::DropboxJs::Client.new('ol56zaikdq4kxjx') # ol56zaikdq4kxjx
        @dropboxpath = "/"
        @dropboxclient.authenticate().then do
          $log.info("logged in at dropbox with full access")
        end

      when "logindrop"
        @dropboxclient = Opal::DropboxJs::Client.new('xr3zna7wrp75zax')
        @dropboxpath = "/"
        @dropboxclient.authenticate().then do
          $log.info("logged in at dropbox with App access")
        end

      when "cddrop"
        @dropboxpath = command_tokens[1] || "/"

      when "pwddrop"
        $log.info(@dropboxpath)

      when "drop"
        $log.info("saving to Dropbox #{@dropboxpath}")

        abc_code = @editor.get_text
        metadata = @abc_transformer.get_metadata(abc_code)
        filebase = "#{metadata[:X]}_#{metadata[:T]}"
        print_variant = @song.harpnote_options[:print][0][:title]

        rootpath = command_tokens[1] || @dropboxpath || "/" # todo ensure that the path has a /

        @dropboxclient.authenticate().then do

          Promise.when(
              @dropboxclient.write_file("#{rootpath}#{filebase}.abc", @editor.get_text),
              @dropboxclient.write_file("#{rootpath}#{filebase}_#{print_variant}_a3.pdf", render_a3(0).output(:raw)),
              @dropboxclient.write_file("#{rootpath}#{filebase}_#{print_variant}_a4.pdf", render_a4(0).output(:raw))
          )
        end.then do
          $log.info("all files saved")
        end.fail do |err|
          $log.error("there was an error saving files #{err}")
        end

      when "lsdrop"
        rootpath = command_tokens[1] || @dropboxpath || "/"
        $log.info("files in Dropbox path #{@dropboxpath}:")


        @dropboxclient.authenticate().then do
          @dropboxclient.read_dir(rootpath)
        end.then do |entries|
          $log.info("<pre>" + entries.select { |entry| entry =~ /\.abc$/ }.join("\n").to_s + "</pre>")
        end

      when "rdrop"
        fileid = command_tokens[1]
        rootpath = command_tokens[2] || @dropboxpath || "/"
        $log.info("get from Dropbox path #{rootpath}#{fileid}_ ...:")

        @dropboxclient.authenticate().then do |error, data|
          @dropboxclient.read_dir(rootpath)
        end.then do |entries|
          $log.puts entries
          file = entries.select { |entry| entry =~ /#{fileid}_.*\.abc$/ }.first
          @dropboxclient.read_file("#{rootpath}#{file}")
        end.then do |abc_text|
          $log.puts "got it"
          @editor.set_text(abc_text)
        end

      else
        $log.error("wrong commnad: #{command}")
    end
  end

  # Save session to local store
  def save_to_localstorage
    abc = @editor.get_text
    abc = `localStorage.setItem('abc_data', abc);`
  end

  # load session from localstore
  def load_from_loacalstorage
    abc = Native(`localStorage.getItem('abc_data')`)
    @editor.set_text(abc) unless abc.nil?
  end

  # render the harpnotes to a3
  def render_a3
    printer = Harpnotes::PDFEngine.new
    printer.draw(layout_harpnotes(0))
  end


  # render the harpnotes splitted on a4 pages
  def render_a4
    Harpnotes::PDFEngine.new.draw_in_segments(layout_harpnotes)
  end

  def play_abc(mode = :song)
    if @harpnote_player.is_playing?
      @harpnote_player.stop()
      Element.find('#tbPlay').html('play')
    else
      Element.find('#tbPlay').html('stop')
      @harpnote_player.play_song(0) if mode == :song
      @harpnote_player.play_selection(0) if mode == :selection
      @harpnote_player.play_from_selection if mode == :selection_ff
    end
  end

  def stop_play_abc
    @harpnote_player.stop()
    Element.find('#tbPlay').html('play')

  end


  # render the previews
  # also saves abc in localstore()
  def render_tunepreview_callback
    begin
      @tune_preview_printer.draw(@editor.get_text)
    rescue Exception => e
      $log.error([e.message, e.backtrace])
    end
    $log.info("#finished Tune")
    set_inactive("#tunePreview")

    nil
  end

  # render the previews
  # also saves abc in localstore()
  def render_harpnotepreview_callback
    begin
      @song_harpnotes = layout_harpnotes(0)
      @harpnote_player.load_song(@song)
      @harpnote_preview_printer.draw(@song_harpnotes)
    rescue Exception => e
      $log.error([e.message, e.backtrace])
    end

    $log.info("finished Haprnotes")
    set_inactive("#harpPreview")

    nil
  end


  def render_previews
    $log.info("rendering")
    save_to_localstorage

    set_active("#tunePreview")
    `setTimeout(function(){self.$render_tunepreview_callback()}, 0)`

    set_active("#harpPreview")
    `setTimeout(function(){self.$render_harpnotepreview_callback()}, 0)`

  end

  # download abc + pdfs as a zip archive
  # todo: determine filename from abc header
  def save_file
    zip = JSZip::ZipFile.new
    zip.file("song.abc", get_abc_code)
    zip.file("harpnotes_a4.pdf", render_a4.output(:raw))
    zip.file("harpnotes_a3.pdf", render_a3.output(:raw))
    blob = zip.to_blob
    filename = "song#{Time.now.strftime("%d%m%Y%H%M%S")}.zip"
    `window.saveAs(blob, filename)`
  end

  # compute the layout of the harpnotes
  # @return [Happnotes::Layout] to be passed to one of the engines for output
  def layout_harpnotes(print_variant = 0)
    @song = Harpnotes::Input::ABCToHarpnotes.new.transform(@editor.get_text)
    Harpnotes::Layout::Default.new.layout(@song, nil, print_variant)
  end

  # highlight a particular abc element in all views
  # note that previous selections are still maintained.
  def highlight_abc_object(abcelement)
    a=Native(abcelement)
    # $log.debug("select_abc_element #{a[:startChar]} (#{__FILE__} #{__LINE__})")

    unless @harpnote_player.is_playing?
      @editor.select_range_by_position(a[:startChar], a[:endChar])
    end

    @tune_preview_printer.range_highlight_more(a[:startChar], a[:endChar])

    @harpnote_preview_printer.range_highlight(a[:startChar], a[:endChar])
  end


  def unhighlight_abc_object(abcelement)
    a=Native(abcelement)
    @tune_preview_printer.range_unhighlight_more(a[:startChar], a[:endChar])
    #$log.debug("unselect_abc_element #{a[:startChar]} (#{__FILE__} #{__LINE__})")

    @harpnote_preview_printer.range_unhighlight(a[:startChar], a[:endChar])
  end

  # select a particular abcelement in all views
  # previous selections are removed
  def select_abc_object(abcelement)
    @harpnote_preview_printer.unhighlight_all();

    highlight_abc_object(abcelement)
  end

  private


  def setup_ui
    # setup the harpnote prviewer
    @harpnote_preview_printer = Harpnotes::RaphaelEngine.new("harpPreview", 1100, 700) # size of canvas in pixels
    @harpnote_preview_printer.set_view_box(0, 0, 440, 297) # this scales the whole thing
    @harpnote_preview_printer.on_select do |harpnote|
      select_abc_object(harpnote.origin)
    end

    # setup tune preview
    printerparams = {staffwidth: 750} #todo compute the staffwidth
    @tune_preview_printer = ABCJS::Write::Printer.new("tunePreview", printerparams)
    @tune_preview_printer.on_select do |abcelement|
      a=Native(abcelement)
      select_abc_object(abcelement)
    end
  end


  def setup_ui_listener

    Element.find("#tbPlay").on(:click) { play_abc(:selection_ff) }
    Element.find("#tbRender").on(:click) { render_previews }
    Element.find("#tbPrintA3").on(:click) { url = render_a3.output(:datauristring); `window.open(url)` }
    Element.find("#tbPrintA4").on(:click) { url = render_a4.output(:datauristring); `window.open(url)` }
    Element.find("#tbCommand").on(:change) { |event|
      handle_command(Native(event[:target])[:value])
      Native(event[:target])[:value] = ""
    }


    # changes in the editor
    @editor.on_change do |e|
      if @refresh_timer
        `clearTimeout(self.refresh_timer)`
        # `alert("refresh cancelled")`
      end

      if @playtimer_timer
        `setTimeout(function(){$('#tbPlay').html('play')}, 0)`
        `clearTimeout(self.playtimer_timer)`
        # `alert("refresh cancelled")`
      end

      #@playtimer_timer = `setTimeout(function(){self.$play_abc_part(e.data.text), 10})`

      @refresh_timer = `setTimeout(function(){self.$render_previews()}, 2000)`
      nil
    end


    @editor.on_selection_change do |e|
      a = @editor.get_selection_positions
      #$log.debug("editor selecti #{a.first} to #{a.last9}")
      unless a.first == a.last
        @tune_preview_printer.range_highlight(a.first, a.last)
        @harpnote_preview_printer.unhighlight_all
        @harpnote_preview_printer.range_highlight(a.first, a.last)
        @harpnote_player.range_highlight(a.first, a.last)
      end
    end


    @harpnote_player.on_noteon do |e|
      $log.debug("noteon #{Native(e)[:startChar]}")
      highlight_abc_object(e)
    end

    @harpnote_player.on_noteoff do |e|
      $log.debug("noteoff #{Native(e)[:startChar]}")
      unhighlight_abc_object(e)
    end

    @harpnote_player.on_songoff do
      stop_play_abc()
    end

    # key events in editor
    Element.find(`window`).on(:keydown) do |evt|

      $log.debug("key pressed (#{__FILE__} #{__LINE__})")
      `console.log(event)`
      if `evt.keyCode == 13 && evt.shiftKey`
        evt.prevent_default
        render_previews
        `evt.preventDefault()`
      elsif `(event.keyCode == 83 && event.ctrlKey) || (event.which == 19)`
        evt.prevent_default
        save_file
        `evt.preventDefault()`
      end
    end

    # dragbars
    Element.find("#dragbar").on(:mousedown) do |re|
      re.prevent
      Element.find(`document`).on(:mousemove) do |e|
        Element.find("#leftColumn").css(:right, "#{`window.innerWidth` - e.page_x}px")
        Element.find("#rightColumn").css(:left, "#{e.page_x}px")
        Element.find("#dragbar").css(:left, "#{e.page_x}px")
      end
      Element.find(`document`).on(:mouseup) do
        `$(document).unbind('mousemove')`
      end
    end
  end

  def set_active(ui_element)
    Element.find(ui_element).css('background-color', 'red')

  end

  def set_inactive(ui_element)
    Element.find(ui_element).css('background-color', 'white')
  end

end

Document.ready? do
  Controller.new
end
