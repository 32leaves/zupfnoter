module Harpnotes

  module Music

    # This class is used to play the harpnotes
    # todo factor out the dependency of to musicaljs into opal-musicaljs

    class HarpnotePlayer

      def initialize()
        @inst = `new Instrument("piano")`
        @isplaying = false
        @selection = []
      end

      def is_playing?
        @isplaying
      end

      def on_noteon(&block)
        Native(@inst).on(:noteon) do |element|
          abc_element = Native(element)[:origin]
          block.call(abc_element)
          nil
        end
      end


      def on_noteoff(&block)
        Native(@inst).on(:noteoff) do |element|
          abc_element = Native(element)[:origin]
          block.call(abc_element)
          nil
        end
      end

      def on_songoff(&block)
        @songoff_callback = block
      end


      def play_from_selection
        $log.debug(@selection.to_s)

        if @selection.first
          notes_to_play = @voice_elements.select do |n|
            n[:delay] >= @selection.first[:delay]
          end
        else
          $log.error("please select at least one note")
          notes_to_play = []
        end

        play_notes(notes_to_play)
      end

      def play_selection
        play_notes(@selection)
      end

      def play_song
        play_notes(@voice_elements)
      end

      def play_notes(the_notes)
        self.stop()

        unless the_notes.empty?
          #note schedule in secc, SetTimout in msec; finsh after last measure
          `clearTimeout(self.song_off_timer)` if @song_off_timer

          firstnote = the_notes.first
          lastnote = the_notes.last

          # stoptime comes in msec
          stop_time = (lastnote[:delay] - firstnote[:delay] + Harpnotes::Layout::Default::SHORTEST_NOTE * @duration_timefactor) * 1000 # todo factor out the literals
          @song_off_timer = `setTimeout(function(){self.songoff_callback.$call()}, stop_time )`


          the_notes.each do |the_note|
            the_note_to_play = the_note.clone
            the_note_to_play[:delay] -= firstnote[:delay]

            note = the_note_to_play.to_n
            %x{
            self.inst.tone(note);
            self.inst.schedule(note.delay + note.duration, function(){self.inst._trigger("noteoff", note);});
           }
          end
          @isplaying = true
        else
          $log.warn("nothing selected to play")
        end
      end


      def stop()
        `self.inst.silence()`
        @isplaying = false
      end

      def unhighlight_all()
        @selection = []
      end


      def range_highlight(from, to)
        @selection = []
        @voice_elements.sort { |a, b| a[:delay] <=> b[:delay] }.each do |element|

          origin = Native(element[:origin])
          unless origin.nil?
            el_start = origin[:startChar]
            el_end = origin[:endChar]

            if ((to > el_start && from < el_end) || ((to === from) && to === el_end))
              @selection.push(element)
            end
          else
            $log.error("BUG: note without origin #{element.class}")
          end
        end
      end


      def load_song(music)
        specduration = music.meta_data[:tempo][:duration].reduce(:+)
        specbpm = music.meta_data[:tempo][:bpm]

        spectf = (specduration * specbpm)

        # 1/4 = 120 bpm shall be  32 ticks per quarter: convert to 1/4 <-> 128:
        tf = spectf * (128/120)
        @duration_timefactor = 1/tf # convert music duration to musicaljs duration
        @beat_timefactor = 1/(tf * Harpnotes::Layout::Default::BEAT_PER_DURATION) # convert music beat to musicaljs delay

        #todo duration_time_factor, beat_time_factor

        $log.debug("playing with tempo: #{tf} ticks per quarter #{__FILE__} #{__LINE__}")
        @voice_elements = music.voices.each_with_index.map do |voice, index|
          tie_start = {}
          voice.select { |c| c.is_a? Playable }.map do |root|

            velocity = 0.000011 if root.is_a? Pause # pause is highlighted but not to be heard
            to_play = {
                delay: root.beat * @beat_timefactor,
                pitch: -root.pitch,   # todo: why -
                duration: root.duration * @duration_timefactor, # todo: do we need to adjust triplets?
                velocity: 0.2,
                velocity: velocity,
                origin: root.origin
            }

            # todo Handle synchpoints

            # handle ties and slurs

            if root.tie_end?
              if tie_start[:pitch] == to_play[:pitch]
                to_play[:duration] += tie_start[:duration]
                to_play[:delay] = tie_start[:delay]
                result = to_play
              else
                result = [tie_start, to_play]
              end
            end

            if root.tie_start?
              tie_start = to_play
              result = nil
            end

            to_play
          end
        end.flatten.compact # note that we get three nil objects bcause of the voice filter

      end
    end

  end

end