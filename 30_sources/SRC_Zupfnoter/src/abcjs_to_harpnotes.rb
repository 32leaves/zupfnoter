require "native"

module Harpnotes

  # the input faciities, basically the ABCinput stuff.

  module Input

    # The transformer
    # todo:@next_not_marks ...
    class AbcjsToHarpnotes < AbstractAbcToHarpnotes

      class ABCPitchToMidipitch

        def initialize
          #the tones within an octave
          @tonemap = { 'c' => 0,
                       'd' => 1,
                       'e' => 2,
                       'f' => 3,
                       'g' => 4,
                       'a' => 5,
                       'b' => 6 }

          @voice_accidentals   = (0..6).map { |f| 0 }
          @measure_accidentals = (0..6).map { |f| 0 }
          @on_error            = lambda { |line, message| }

          @accidental_pitches = { 'sharp' => 1, 'flat' => -1, 'natural' => 0 }
        end

        def on_error(&block)
          @on_error = block
        end

        # set the key of the Sheet
        # @param key [key as provided by ABCjs]
        # @return self
        def set_key(key)
          @voice_accidentals = (0..6).map { |f| 0 }
          nkey               = Native(key)
          accidentals        = Native(key)[:accidentals]
          accidentals.each do |accidental|
            a                                               = Native(accidental)
            @voice_accidentals[@tonemap[a[:note].downcase]] = @accidental_pitches[a[:acc].downcase]
            self
          end

          self
        end


        def reset_measure_accidentals
          @measure_accidentals = @measure_accidentals.map { |f| 0 }
        end

        #@param note [Object] Note as provided by abc_parser
        #@return [Integer] midi pitch of the note
        # http://computermusicresource.com/midikeys.html
        # @param [Object] persist_accidentals if set to false, accidentals are considered for the current note only but
        # but not persisted in the measure. This is used, in case of rests, which get their pitch from the subsequent note
        # which invokes its pitch again on its own. In case of a "neutral" accidental persisting the same would make
        # apply the neutral too early!.
        # this covers a but which is in the get_midipitch algorithm
        def get_midipitch(note, persist_accidentals = true)

          native_note = Native(note)
          abc_pitch   = native_note[:pitch]
          scale       = [0, 2, 4, 5, 7, 9, 11]

          octave = (abc_pitch / 7).floor

          note_in_octave      = abc_pitch % 7
          note_in_octave      += 7 if note_in_octave < 0

          # add accidentals by key
          acc_by_key          = @voice_accidentals[note_in_octave]

          # handle accidentals in measure
          note_accidental     = native_note[:accidental]
          measure_accidentals = @measure_accidentals.clone
          if (note_accidental) then
            pitch_delta = @accidental_pitches[note_accidental]
            if pitch_delta == 0 then
              if measure_accidentals[note_in_octave] != 0
                pitch_delta = 0
              else
                pitch_delta = -1 * @voice_accidentals[note_in_octave]
              end
            end
            measure_accidentals[note_in_octave] = pitch_delta
          end
          acc_by_measure       = measure_accidentals[note_in_octave]
          @measure_accidentals = measure_accidentals.clone if persist_accidentals

          # 60 is the C in 3rd Octave
          result               = 60 + 12 * octave + scale[note_in_octave] + acc_by_key + acc_by_measure

          result
        end
      end

      def initialize
        super
        @pitch_transformer = ABCPitchToMidipitch.new()
        @abc_code          = nil
        @previous_new_part = []
        reset_state
      end


      # @param [String] zupfnoter_abc to be transformed
      #
      # @return [Harpnotes::Music::Song] the Song
      def transform(zupfnoter_abc)
        @abc_code        = zupfnoter_abc

        # get harpnote_options from abc_code
        # todo remove this compatibility mode
        harpnote_options = parse_harpnote_config(zupfnoter_abc)

        # note that harpnote_options uses singular names
        if $conf.get("location") == "song"
          @annotations = $conf.get("annotations")
        else #todo compatibility code

          @annotations = (harpnote_options[:annotation] || [])
          @annotations = @annotations.inject({}) do |hash, entry|
            hash[entry[:id]] = entry
            hash
          end
        end


        # now parse the abc_code by abcjs
        # todo move this to opal-abcjs
        %x{
          var parser = new ABCJS.parse.Parse();
          parser.parse(#{@abc_code});
          var warnings = parser.getWarningObjects();
          var tune = parser.getTune();
          // todo handle parser warnings
          //console.log(tune);
          //console.log(JSON.stringify(tune));
        }

        warnings = [Native(`warnings`)].flatten.compact
        warnings.each { |w|
          wn                = Native(w)
          line_no, char_pos = charpos_to_line_column(wn[:startChar])
          msg               = "#{wn[:message]} at line #{wn[:line]} at [#{line_no}:#{char_pos}]"
          $log.warning(msg, [line_no, char_pos], [line_no, char_pos + 1])
        }

        #
        # pull out the headlines
        # todo:factor out to a generic method parse_abc_header()
        #

        note_length = get_metadata(zupfnoter_abc)[:L] || $conf.get("defaults.note_length")
        note_length = note_length.split('/').map{|s| s.strip.to_i} #|| '1/4').split.map { |s| s.strip.to_i }


        # extract the lines
        tune             = Native(`tune`)
        lines            = tune[:lines].select { |l| Native(l)[:staff] } # filter out subtitles


        # get the key
        first_staff      = Native(Native(lines.first)[:staff].first)
        key              = first_staff[:key]
        @pitch_transformer.set_key(key)

        #get the meter
        meter = {
            :type => first_staff[:meter][:type]
        }
        if meter[:type] == "specified"
          meter[:den]     = Native(first_staff[:meter][:value].first)[:den]
          meter[:num]     = Native(first_staff[:meter][:value].first)[:num]
          meter[:display] = "#{meter[:num]}/#{meter[:den]}"
        elsif meter[:display] = meter[:type]
        end

        # extract the voices from the abc model
        voices = []
        lines.each_with_index do |line, line_index|
          voice_no = 1
          Native(line)[:staff].each_with_index do |staff, staff_index|
            Native(staff)[:voices].each_with_index do |voice, voice_index|
              $log.debug("reading line.staff.voice #{voice_no}:#{line_index} #{staff_index}.#{voice_index} (#{__FILE__} #{__LINE__})")
              voices[voice_no] ||= Harpnotes::Music::Voice.new()
              voices[voice_no] << voice.map { |x| Native(x) }
              voices[voice_no].index = voice_no
              voices[voice_no].flatten!
              voice_no += 1
            end
          end
        end
        voices.compact!

        ##################################################################
        # transform the voices
        hn_voices = voices.each_with_index.map do |voice, voice_idx|
          reset_state

          @pitch_providers = voice.map do |el|
            result = nil
            result = el if el[:pitches]
          end

          # transform the voice content
          hn_voice         = voice.each_with_index.map do |el, i|

            type             = el[:el_type]
            hn_voice_element = self.send("transform_#{type}", el, i)

            if el[:startChar]
              # fix character position in abc
              el[:startChar] -= 3 if el[:startChar] == el[:endChar] # fix ananomaly of abc2js chords have no range

              end_char   = el[:endChar]
              start_char = el[:startChar]
              start_pos  = charpos_to_line_column(start_char) if start_char > 0
              end_pos    = charpos_to_line_column(end_char) if end_char > 0

              # apply uptracing information to the harpnote elements
              unless hn_voice_element.nil? or hn_voice_element.empty?
                hn_voice_element.each do |e|
                  e.origin    = mk_origin(el) # el # todo: pass a hash only {}
                  e.start_pos = start_pos # necessary for error reporting in editor
                  e.end_pos   = end_pos

                  if e.is_a?(Harpnotes::Music::SynchPoint)
                    e.notes.each do |synchpoint_note|
                      synchpoint_note.start_pos = start_pos
                      synchpoint_note.end_pos   = end_pos
                    end
                  end
                end

              end
            end

            hn_voice_element
          end.flatten.compact

          # compute the explicit jumplines
          jumplines        = []
          hn_voice.each do |e|
            jumplines << make_jumplines(e)
          end
          hn_voice              += jumplines.flatten.compact


          # note bound annotations

          notebound_annotations = []
          hn_voice.each do |e|
            notebound_annotations << make_notebound_annotations(e)
          end

          hn_voice += notebound_annotations.flatten.compact


          hn_voice
        end

        #############################
        # now construct the song
        hn_voices.unshift(hn_voices.first) # let voice-index start with 1 -> duplicate voice 0
        result    = Harpnotes::Music::Song.new(hn_voices, note_length)

        # contruct the meta data
        meta_data = { :compile_time => Time.now(),
                      :meter        => meter[:display],
                      :key          => Native(key)[:root] + Native(key)[:acc] + Native(key)[:mode]
        }

        # augment metadata by appending annotations with
        # the abc-key. This is supported only for dedicated
        # information fields
        { key: "K:" }.each do |k, v|
          if @annotations[v]
            meta_data[k] = meta_data[k] + (@annotations[v][:text] || "")
          end
        end

        # handling tempo
        # tempo is marked as duration, ... duration = bpm
        duration                  = 0.25; bpm = 120 # default speed settings #todo make this configurable
        # note that duration from metadata is an array, so the default needs to be an array too.
        meta_data[:tempo]         = { duration: [duration], bpm: bpm } # setting the default speed
        meta_data[:tempo_display] = "1/#{1/duration} = #{bpm}"
        if tune[:metaText][:tempo]
          duration = tune[:metaText][:tempo][:duration] rescue meta_data[:tempo][:duration]
          bpm = tune[:metaText][:tempo][:bpm] rescue meta_data[:tempo][:bpm]
          meta_data[:tempo]         = { duration: duration, bpm: bpm }
          duration_display          = duration.map { |d| "1/#{1/d}" }
          meta_data[:tempo_display] = [tune[:metaText][:tempo][:preString],
                                       duration_display, "=", bpm,
                                       tune[:metaText][:tempo][:postString]
          ].join(" ")
        end

        # handle meta data from tune as parsed by abcjs
        meta_data_from_tune = Hash.new(tune[:metaText].to_n)
        meta_data_from_tune.keys.each { |k| meta_data[k] = meta_data_from_tune[k] } # todo could not get Hash(object) and use merge
        result.meta_data        = meta_data


        # handle harpnote options (the %%%%hn.xxxx - coments)
        result.harpnote_options = {}
        print_options           = Confstack.new
        print_options.push($conf.get("defaults.print"))

        # handle print options
        result.harpnote_options[:print] = (harpnote_options[:print] || [{}]).each_with_index.map do |specified_option, index|
          print_options.push(specified_option)

          resulting_options = {
              view_id:      index,
              title:        print_options.get('t'),
              startpos:     print_options.get('startpos'),
              voices:       (print_options.get('v')), #.map { |i| i-1 },
              synchlines:   (print_options.get('s')), #.map { |i| i.map { |j| j-1 } },
              flowlines:    (print_options.get('f')), #.map { |i| i-1 },
              subflowlines: (print_options.get('sf')), #.map { |i| i-1 },
              jumplines:    (print_options.get('j')), # .map { |i| i-1 },
              layoutlines:  (print_options.get('l') || print_options.get('v')) # .map { |i| i-1 } # these voices are considered in layoutoptimization
          }

          # checking missing voices
          missing_voices    = (resulting_options[:voices] - resulting_options[:layoutlines]).map { |i| i + 1 }
          $log.error("hn.print '#{resulting_options[:title]}' l: missing voices #{missing_voices.to_s}") unless missing_voices.empty?

          print_options.pop
          msg = "hn.print '#{resulting_options[:title]}' l: missing voices #{missing_voices.to_s}"
          $log.error(msg, [line_no, 1]) unless missing_voices.empty?
          resulting_options
        end

        #todo:this is a compatibility code - remove after conversion to the new configuration
        if $conf.get("location") == "song"
          result.harpnote_options[:print] = $conf.get("produce").map do |i|
            title = $conf.get("extract.#{i}.title")
            if title
              { title: title, view_id: i }
            else
              $log.error("could not find extract number #{i}", [1, 1], [1000, 1000])
              nil
            end
          end.compact
        end

        # legend
        print_options = Confstack.new
        print_options.push($conf.get('defaults.legend'))
        print_options.push(harpnote_options[:legend]) if harpnote_options[:legend]
        result.harpnote_options[:legend] = print_options.get

        # lyrics
        print_options                    = Confstack.new
        print_options.push($conf.get('defaults.lyrics'))
        print_options.push(harpnote_options[:lyrics]) if harpnote_options[:lyrics]
        result.harpnote_options[:lyrics]        = print_options.get
        result.harpnote_options[:lyrics][:text] = meta_data[:unalignedWords] || []

        # notes
        result.harpnote_options[:notes]         = harpnote_options[:note] || []

        result
      end

      # get column und line number of abc_code
      # based on the character position
      #
      # @param [Numeric] charpos character position in abc code
      # @return [Numeric] charpos, line_no
      def charpos_to_line_column(charpos)
        lines    = @abc_code[1, charpos].split("\n")
        line_no  = lines.count
        char_pos = lines.last.length()
        return line_no, char_pos
      end

      private

      # extract chords from an entity
      # chords might have multiple lines
      # so we split the lines as well
      #
      # @param [Object] entity the note  from abcjs
      # @return [Array of String] an array of chord entries
      def _extract_chord_lines(entity)
        result = []
        unless entity[:chord].nil?
          entity[:chord].each do |chord|
            text = Native(chord)[:name]
            text.split("\n").each do |line|
              result << line
            end
          end
        end
        result
      end

      # extract variant endings
      # @param [Object] entity the music entity from which we extract the variant
      # @return [String] the label of the variant ending
      def _extract_variant_ending(entity)
        result = nil
        if entity[:startEnding]
          result = entity[:startEnding]
        end
        result
      end

      #@param entity []
      def make_jumplines(entity)
        result = []
        if entity.is_a? Harpnotes::Music::Playable ## todo handle jumplines by Note attributes only without referring to
          chords =_extract_chord_lines(entity.origin)
          chords.each do |name|
            if name[0] == '@'
              nameparts  = name[1..-1].split("@")
              targetname = nameparts[0]
              target     = @jumptargets[targetname]
              argument   = nameparts[1] || 1
              argument   = argument.to_i
              if target.nil?
                $log.error("target '#{targetname}' not found in voice at #{entity.start_pos_to_s}", entity.start_pos, entity.end_pos)
              else
                result << Harpnotes::Music::Goto.new(entity, target, distance: argument) #todo: better algorithm
              end
            else
              #result << Harpnotes::Music::Annotation.new(name, )
            end
          end
        end

        result
      end

      def make_notebound_annotations(entity)
        result = []
        if entity.is_a? Harpnotes::Music::Playable
          chords =_extract_chord_lines(entity.origin)
          chords.each do |name|

            match = name.match(/^([!#])([^\@]+)(\@(\-?[0-9\.]+),(\-?[0-9\.]+))?$/)
            if match
              semantic = match[1]
              text     = match[2]
              pos_x    = match[4] if match[4]
              pos_y    = match[5] if match[5]
              case semantic
                when "#"
                  annotation = @annotations[text]
                  $log.error("could not find annotation #{text}", entity.start_pos, entity.end_pos) unless annotation
                when "!"
                  annotation = { text: text }
                else
                  annotation = nil # it is not an annotation
              end

              if annotation
                notepos  = [pos_x, pos_y].map { |p| p.to_f } if pos_x
                position = notepos || annotation[:pos] || [2, -5] #todo: make default position configurable
                result << Harpnotes::Music::NoteBoundAnnotation.new(entity, { pos: position, text: annotation[:text] })
              end
            else
              # $log.error("syntax error in annotation: #{name}")
            end
          end
        end
        result
      end

      def transform_note(note, index=0)
        # 1/64 is the shortest note being handled
        # note that this scaling also has an effect
        # on the layout (DURATION_TO_STYLE). So, don't change this.
        # todo: we need to separate duration from the layout

        duration     = ($conf.get('layout.SHORTEST_NOTE') * note[:duration]).round

        start_tuplet = true if note[:startTriplet]
        end_tuplet   = true if note[:endTriplet]
        if @tuplet_downcount > 1
          @tuplet_downcount -= 1
        else
          @tuplet_downcount = note[:startTriplet] || 1
          @current_tuplet   = @tuplet_downcount
        end

        if not note[:rest].nil?
          if note[:rest][:type] == 'spacer' # 'spacers' are not played: http://abcnotation.com/wiki/abc:standard:v2.1#typesetting_extra_space
            result = []
          else
            pitch_note = @pitch_providers[index .. -1].compact.first
            result     = transform_rest(note, duration, pitch_note)
          end
        else
          result = transform_real_note(note, duration)
        end

        if not result.empty?

          result.first.tuplet       = @current_tuplet
          result.first.tuplet_start = start_tuplet
          result.first.tuplet_end   = end_tuplet

          # support the case of repetitions from the very beginning

          if @repetition_stack.empty?
            @repetition_stack << result.last
          end

          # collect chord based targets
          chords   = _extract_chord_lines(note)
          #jumpstarts = []
          jumpends = []
          chords.each do |name|
            if name[0] == ':'
              jumpends.push name[1 .. -1]
              @jumptargets[name[1 .. -1]] = result.select { |n| n.is_a? Harpnotes::Music::Playable }.last
            end
            if name[0] =="@"
              #jumpstarts.push name[1 .. -1]
            end
          end
        end

        result
      end


      #todol factor out handling of measures and newparts
      def transform_rest(note, duration, pitch_note=nil)

        pitch = 60
        pitch = @previous_note.pitch if @previous_note
        pitch = @pitch_transformer.get_midipitch(Native(pitch_note[:pitches]).first, false) unless pitch_note.nil?

        rest           = Harpnotes::Music::Pause.new(pitch, duration)
        rest.origin    = mk_origin(note)
        rest.visible   = false if note[:rest][:type] == 'invisible'
        @previous_note = rest

        result = [rest]
        if @next_note_marks[:measure]
          result << Harpnotes::Music::MeasureStart.new(rest)
          @next_note_marks[:measure] = false
        end

        if @next_note_marks[:repeat_start]
          @repetition_stack << rest
          @next_note_marks[:repeat_start] = false
        end

        if @next_note_marks[:variant_ending]
          result << Harpnotes::Music::NoteBoundAnnotation.new(@previous_note, { pos: [0, 0], text: @next_note_marks[:variant_ending] })
          @next_note_marks[:variant_ending]
        end

        @previous_new_part.each { |part|
          part.companion    = rest
          rest.first_in_part=true
        }
        @previous_new_part.clear

        result
      end

      def transform_real_note(note, duration)
        notes = Native(note[:pitches]).map do |pitch|
          midipitch           = @pitch_transformer.get_midipitch(pitch)
          native_pitch        = Native(pitch)
          thenote             = Harpnotes::Music::Note.new(midipitch, duration)
          thenote.origin      = mk_origin(note)
          # we always deliver arrays; this avoids if statements in layouter
          thenote.slur_starts = (native_pitch[:startSlur] || []).map { |s| Native(s)[:label] }
          thenote.slur_ends   = native_pitch[:endSlur] || []
          thenote.tie_start   = (not native_pitch[:startTie].nil?)
          thenote.tie_end     = (not native_pitch[:endTie].nil?)
          thenote
        end

        result = []
        if notes.length == 1
          result << notes.first
        else
          synchpoint             = Harpnotes::Music::SynchPoint.new(notes) # note that notes are alreday Playables
          synchpoint.slur_starts = (note[:startSlur] || []).map { |s| Native(s)[:label] }
          synchpoint.slur_ends   = note[:endSlur] || []
          # note that we pull the tie starts from the inner notes
          # todo: do we need this for the slurs as well
          synchpoint.tie_start   = (not note[:startTie].nil?) || (not notes.select { |n| n.tie_start? }.empty?)
          synchpoint.tie_end     = (not note[:endTie].nil?) || (not notes.select { |n| n.tie_end? }.empty?)

          result << synchpoint
        end

        @previous_new_part.each { |part|
          result.last.first_in_part = true
          part.companion            = notes.first
        }
        @previous_new_part.clear

        @previous_note = result.last

        if @next_note_marks[:measure]
          notes.each { |note| result << Harpnotes::Music::MeasureStart.new(note) }
          @next_note_marks[:measure] = false
        end

        if @next_note_marks[:repeat_start]
          @repetition_stack << notes.first
          @next_note_marks[:repeat_start] = false
        end

        if @next_note_marks[:variant_ending]
          result << Harpnotes::Music::NoteBoundAnnotation.new(@previous_note, { pos: [4, -2], text: @next_note_marks[:variant_ending] })
          @next_note_marks[:variant_ending] = nil
        end

        result
      end

      def transform_bar(bar)
        type                              = bar[:type]
        @next_note_marks[:measure]        = true
        @next_note_marks[:variant_ending] = _extract_variant_ending(bar)
        @pitch_transformer.reset_measure_accidentals
        send("transform_#{type.gsub(" ", "_")}", bar)
        # todo handle variant endings
      end

      def transform_bar_invisible(bar)
        @next_note_marks[:measure] = false
        nil
      end

      def transform_bar_thin(bar)
        nil
      end

      def transform_bar_left_repeat(bar)
        @next_note_marks[:repeat_start] = true
        nil
      end

      def transform_bar_thin_thick(bar)
        nil
      end

      def transform_bar_right_repeat(bar)
        if @repetition_stack.length == 1
          start = @repetition_stack.last
        else
          start = @repetition_stack.pop
        end

        distance = 2
        _extract_chord_lines(bar).each do |line|
          level = line.split('@')
          if level[2]
            level = level[2] # note that "^@@distance"
            $log.debug("bar repeat level #{level} #{__FILE__}:#{__LINE__}")
            distance = level.to_i unless level.nil?
          end
        end

        [Harpnotes::Music::Goto.new(@previous_note, start, distance: distance)]
      end

      def transform_part(part)
        new_part        = Harpnotes::Music::NewPart.new(part[:title])
        new_part.origin = mk_origin(part)
        @previous_new_part << new_part
        [new_part]
      end

      def method_missing(name, *args)
        $log.debug("Missing transformation rule: #{name} (#{__FILE__} #{__LINE__})")
        nil
      end

    end

  end

end
