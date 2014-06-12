require 'opal-jquery'
require 'opal-jszip'
require 'opal-jspdf'
require 'harpnotes'
require 'abc_to_harpnotes'
require 'raphael_engine'
require 'pdf_engine'
require 'consolelogger'


class Controller

  def initialize
    $log = ConsoleLogger.new("consoleEntries")

    setup_editor
    setup_ui
    setup_ui_listener
  end

  def render_pdf
    Harpnotes::PDFEngine.new.draw(layout_harpnotes)
  end

  def play_abc
    if @inst
      Element.find('#tbPlay').html('play')
      `self.inst.silence();`
      @inst = nil;
    else
      Element.find('#tbPlay').html('stop')
      @inst = `new Instrument('piano')`
      `self.inst.play({tempo:200}, #{get_abc_code}, function(){self.$play_abc()} )`  # todo get parameter from ABC
    end
  end


  def play_abc_part(string)
      @inst = `new Instrument('piano')`
      `self.inst.play({tempo:200}, #{string});`  # todo get parameter from ABC
  end

  def render_previews
    $log.info("rendering")
    begin
      @harpnote_preview_printer.draw(layout_harpnotes)
    rescue Exception =>e
      $log.error(e.message)
    end
    begin
      @tune_preview_printer.draw(get_abc_code)
    rescue Exception =>e
      $log.error(e.message)
    end
=begin
    %x{
    var top = $("#tunePreview").scrollTop();
    var width = $("#tunePreview").width();
    ABCJS.renderAbc($("#tunePreview")[0], #{get_abc_code}, {}, {}, {})
    $("#tunePreview").scrollTop(top);
    $("#tunePreview").width(width);
    }
=end

    nil
  end

  def save_file
    zip = JSZip::ZipFile.new
    zip.file("song.abc", get_abc_code)
    zip.file("harpnotes.pdf", render_pdf.output(:raw))
    blob = zip.to_blob
    filename = "song#{Time.now.strftime("%d%m%Y%H%M%S")}.zip"
    `window.saveAs(blob, filename)`
  end

  def get_abc_code
    `self.editor.getSession().getValue()`
  end

  def layout_harpnotes
    song = Harpnotes::Input::ABCToHarpnotes.new.transform(get_abc_code)
    Harpnotes::Layout::Default.new.layout(song)
  end

  def select_note(note, origin)
    `console.log(note)`
    alert "Selection from #{origin}"
  end

  private

  def setup_editor
    %x{
      var editor = ace.edit("abcEditor");
      editor.setTheme("ace/theme/tomorrow_night");
    }
    @editor = `editor`
  end

  def setup_ui
    # setup the harpnote prviewer
    @harpnote_preview_printer = Harpnotes::RaphaelEngine.new("harpPreview")
    @harpnote_preview_printer.on_select do |origin|
      select_note(origin, :harpnotes)
    end


    printerparams = {}
    @tune_preview_printer = ABCJS::Write::Printer.new("tunePreview")
  end

  def setup_ui_listener

    Element.find("#tbPlay").on(:click) { play_abc }
    Element.find("#tbRender").on(:click) { render_previews }
    Element.find("#tbPrint").on(:click) { url = render_pdf.output(:datauristring); `window.open(url)` }

    Native(Native(@editor).getSession).on(:change){|e|
      if @refresh_timer
        `clearTimeout(self.refresh_timer)`
       # `alert("refresh cancelled")`
      end

      if @playtimer_timer
        `clearTimeout(self.playtimer_timer)`
        # `alert("refresh cancelled")`
      end

      @playtimer_timer = `setTimeout(function(){self.$play_abc_part(e.data.text), 10})`
      @refresh_timer = `setTimeout(function(){self.$render_previews()}, 1000)`
        nil
    }



    Element.find(`window`).on(:keydown) do |evt|
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

end

Document.ready? do
  Controller.new
end
