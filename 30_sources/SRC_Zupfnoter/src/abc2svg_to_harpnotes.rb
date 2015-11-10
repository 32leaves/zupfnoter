require "native"

module Harpnotes
  # the input faciities, basically the ABCinput stuff.

  module Input

    class Abc2svgToHarpnotes < AbstractAbcToHarpnotes

      ABC2SVG_DURATION_FACTOR = 1536


      def initialize
        super
        @abc_code          = nil
        @previous_new_part = []

        @part_table = {}

        @_shortest_note = $conf.get('layout.SHORTEST_NOTE')
        _reset_state
      end

      # @param [String] zupfnoter_abc to be transformed
      #
      # @return [Harpnotes::Music::Song] the Song
      def transform(zupfnoter_abc)
        @abc_code    = zupfnoter_abc
        @annotations = $conf.get("annotations")

        @info_fields = get_metadata(@abc_code)

        abc_parser = ABC2SVG::Abc2Svg.new(nil, { mode: :model }) # first argument is the container for SVG
        @abc_model = abc_parser.get_abcmodel(zupfnoter_abc)

        result = _transform_voices

        result.meta_data        = _make_metadata
        result.harpnote_options = _make_harpnote_options

        result
      end

      def _make_harpnote_options
        result = { lyrics: { text: @info_fields[:W] } }

        result[:print] = $conf.get("produce").map do |i|
          title = $conf.get("extract.#{i}.title")
          if title
            { title: title, view_id: i }
          else
            $log.error("could not find extract number #{i}", [1, 1], [1000, 1000])
            nil
          end
        end.compact
        result
      end

      def _get_key_by_accidentals(accidentals)
        {
            7  => 'C#', #,	A#m	G#Mix	D#Dor	E#Phr	F#Lyd	B#Loc
            6  => 'F#', #	D#m	C#Mix	G#Dor	A#Phr	BLyd	E#Loc
            5  => 'B', #	G#m	F#Mix	C#Dor	D#Phr	ELyd	A#Loc
            4  => 'E', #'C#m	BMix	F#Dor	G#Phr	ALyd	D#Loc
            3  => 'A', #	F#m	EMix	BDor	C#Phr	DLyd	G#Loc
            2  => 'D', #	Bm	AMix	EDor	F#Phr	GLyd	C#Loc
            1  => 'G', #	Em	DMix	ADor	BPhr	CLyd	F#Loc
            0  => 'C', #	Am	GMix	DDor	EPhr	FLyd	BLoc
            -1 => 'F', #	Dm	CMix	GDor	APhr	BbLyd	ELoc
            -2 => 'Bb', #	Gm	FMix	CDor	DPhr	EbLyd	ALoc
            -3 => 'Eb', #	Cm	BbMix	FDor	GPhr	AbLyd	DLoc
            -4 => 'Ab', #	Fm	EbMix	BbDor	CPhr	DbLyd	GLoc
            -5 => 'Db', #	Bbm	AbMix	EbDor	FPhr	GbLyd	CLoc
            -6 => 'Gb', #	Ebm	DbMix	AbDor	BbPhr	CbLyd	FLoc
            -7 => 'Cb' #	Abm	GbMix	DbDor	EbPhr	FbLyd	BbLoc
        }[accidentals]
      end

      def _make_metadata
        key           = _get_key_by_accidentals(@abc_model[:voices].first[:voice_properties][:key][:k_sf])
        o_key         = _get_key_by_accidentals(@abc_model[:voices].first[:voice_properties][:okey][:k_sf])
        o_key_display =""
        o_key_display = "(Original in #{o_key})" unless key == o_key

        tempo_id = @abc_model[:music_type_ids][:tempo]
        tempo_note = @abc_model[:voices].first[:voice_properties][:sym][:extra][tempo_id] rescue nil

        if tempo_note
          duration         = tempo_note[:tempo_notes].map { |i| i / ABC2SVG_DURATION_FACTOR }
          duration_display = duration.map { |d| "1/#{1/d}" }
          bpm              = tempo_note[:tempo_value].to_i
          tempo            = { duration: duration, bpm: bpm }
        else
          duration         = [0.25]
          duration_display = duration.map { |d| "1/#{1/d}" }
          bpm              = 120
          tempo            = { duration: duration, bpm: bpm }
        end

        { composer:      (@info_fields[:C] or []).join("\n"),
          title:         (@info_fields[:T] or []).join("\n"),
          filename:      (@info_fields[:F] or []).join("\n"),
          tempo:         { duration: duration, bpm: bpm },
          tempo_display: [duration_display, "=", bpm].join(' '),
          meter:         @info_fields[:M],
          key:           "#{key} #{o_key_display}"
        }
      end

      private


      # This resets the converter
      # to be called when beginning a new voice
      def _reset_state

        @jumptargets = {} # the lookup table for jumps

        @next_note_marks   = { measure:        false,
                               repeat_start:   false,
                               variant_ending: nil }
        @previous_new_part = []
        @previous_note     = nil
        @repetition_stack  = []

        @tie_started       = false
        @slurstack         = 0
        @tuplet_count      = 1
        @tuplet_down_count = 1

        nil
      end


      def _transform_voices

        part_id = @abc_model[:music_type_ids][:part] # performance ...
        note_id = @abc_model[:music_type_ids][:note]

        # get parts
        @abc_model[:voices].first[:symbols].each do |voice_model_element|
          part                                         = ((voice_model_element[:extra] or {})[part_id] or {})[:text]
          @part_table[voice_model_element[:time].to_s] = part if part
        end

        hn_voices = @abc_model[:voices].each_with_index.map do |voice_model, voice_index|

          _reset_state
          @pitch_providers = voice_model[:symbols].map do |voice_model_element|
            nil
            voice_model_element if voice_model_element[:type] == note_id
          end

          result                = voice_model[:symbols].each_with_index.map do |voice_model_element, index|
            type = @abc_model[:music_types][voice_model_element[:type]]
            begin
              result = self.send("_transform_#{type}", voice_model_element, index)
            rescue Exception => e
              $log.error("BUG: #{e}", charpos_to_line_column(voice_model_element[:istart]))
              nil
            end
            result
          end

          # handle the jumplines
          result                = result.flatten
          jumplines             = result.inject([]) do |jumplines, element|
            jumplines << _make_jumplines(element)
            jumplines
          end

          #handle notebound annotations

          notebound_annotations = result.inject([]) do |notebound_annotations, element|
            notebound_annotations << _make_notebound_annotations(element)
          end

          result += (jumplines + notebound_annotations)

          result = result.flatten.compact

          if (result.count == 0)
            $log.error("Empty voice #{voice_index}")
            result = nil
          end
          result
        end.compact

        hn_voices.unshift(hn_voices.first) # let voice-index start with 1 -> duplicate voice 0
        Harpnotes::Music::Song.new(hn_voices)
      end

      def _transform_bar(voice_element)
        result = []
        type   = voice_element[:bar_type]

        @next_note_marks[:measure]        = true
        @next_note_marks[:variant_ending] = voice_element[:text]
        @next_note_marks[:repeat_start]   = true if ['|:', '::'].include?(type)

        result << _transform_bar_repeat_end(voice_element) if [':|', '::'].include?(type)
      end

      def _transform_note(voice_element)
        origin                           = _parse_origin(voice_element)
        start_pos, end_pos               = origin[:startChar], origin[:endChar]

        #handle tuplets
        tuplet, tuplet_end, tuplet_start = _parse_tuplet_info(voice_element)

        # transform the individual notes
        notes                            = voice_element[:notes].map do |the_note|
          duration = _convert_duration(the_note[:dur])


          result           = Harpnotes::Music::Note.new(the_note[:midi], duration)
          result.origin    = origin
          result.start_pos = charpos_to_line_column(start_pos) # get column und line number of abc_code
          result.end_pos   = charpos_to_line_column(end_pos)

          result.tuplet       = tuplet
          result.tuplet_start = tuplet_start
          result.tuplet_end   = tuplet_end

          result
        end

        # the postprocessing
        # support the case of repetitions from the very beginning

        if @repetition_stack.empty?
          @repetition_stack << notes.last
        end

        result = []
        if notes.count == 1
          result << notes.first
        else
          # handle duration and orign
          synchpoint              = Harpnotes::Music::SynchPoint.new(notes)
          first_note              = notes.first
          synchpoint.duration     = first_note.duration
          synchpoint.origin       = first_note.origin
          synchpoint.start_pos    = first_note.start_pos
          synchpoint.end_pos      = first_note.end_pos

          #handle tuplets of synchpoint
          synchpoint.tuplet       = first_note.tuplet
          synchpoint.tuplet_start = first_note.tuplet_start
          synchpoint.tuplet_end   = first_note.tuplet_end

          result << synchpoint
        end

        # handle ties
        # note that abc2svg only indicates tie start by  voice_element[:ti1] but has no tie end
        result.first.tie_end     = @tie_started
        @tie_started             = !voice_element[:ti1].nil?
        result.first.tie_start   = @tie_started


        # handle slurs
        # note that rests do not have slurs in practise
        result.first.slur_starts = _parse_slur(voice_element[:slur_start]).map { |i| _push_slur() }
        amount_of_slur_ends      = (voice_element[:slur_end] or 0)
        result.first.slur_ends   = (1 .. amount_of_slur_ends).map { _pop_slur } # pop_slur delivers an id.


        #result = [result] # make it an array such that we can append further elements

        if @next_note_marks[:measure]
          notes.each { |note| result << Harpnotes::Music::MeasureStart.new(note) }
          @next_note_marks[:measure] = false
        end

        _make_repeats_jumps_annotations(result, voice_element)

        result
      end

      def _convert_duration(raw_duration)
        duration = [128, ((raw_duration/ABC2SVG_DURATION_FACTOR) * @_shortest_note).round].min
      end


      # @param [Integer] index  - this is required to determine the pitch of the rest
      def _transform_rest(voice_element, index)

        origin             = _parse_origin(voice_element)
        start_pos, end_pos = origin[:startChar], origin[:endChar]

        pitch_note = (@pitch_providers[index .. -1].compact.first or @pitch_providers[0..index-1].compact.last)
        if pitch_note
          pitch = pitch_note[:notes].first[:midi]
        else
          pitch = 60
        end

        if (pitch.nil?)
          raise("undefined pitch")
          pitch = 60
        end

        the_note                         = voice_element[:notes].first
        duration                         = _convert_duration(the_note[:dur])
        tuplet, tuplet_end, tuplet_start = _parse_tuplet_info(voice_element)

        result              = Harpnotes::Music::Pause.new(pitch, duration)
        result.origin       = _parse_origin(voice_element)
        result.start_pos    = charpos_to_line_column(start_pos) # get column und line number of abc_code
        result.end_pos      = charpos_to_line_column(end_pos)

        #handle tuplets of synchpoint
        result.tuplet       = tuplet
        result.tuplet_start = tuplet_start
        result.tuplet_end   = tuplet_end

        result.visible      = false if voice_element[:invisible]

        # the post processing

        # support the case of repetitions from the very beginning

        if @repetition_stack.empty?
          @repetition_stack << result
        end

        result = [result]

        if @next_note_marks[:measure]
          result << Harpnotes::Music::MeasureStart.new(result.first)
          @next_note_marks[:measure] = false
        end


        _make_repeats_jumps_annotations(result, voice_element)

        result
      end

      def _transform_yspace(voice_element, index)
        #  This is a stub for future expansion
      end

      def _transform_bar_repeat_end(bar)
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

      def _transform_format(voice_element)
        nil #`debugger`
      end


      def _transform_meter(voice_element)
        nil #`debugger`
      end

      def _transform_clef(voice_element)
        nil #`debugger`
      end

      # make the jumplilnes
      # @param [Playable] element - an element of the converted voice
      def _make_jumplines(element)
        if element.is_a?(Harpnotes::Music::Playable)
          chords = _extract_chord_lines(element.origin[:raw])
          chords.select { |c| c[0] == '@' }.inject([]) do |result, chord|
            nameparts = chord.split('@')

            targetname = nameparts[1]
            target     = @jumptargets[targetname]

            argument = nameparts[2] || 1
            argument = argument.to_i
            if target.nil?
              $log.error("target '#{targetname}' not found in voice at #{element.start_pos_to_s}", element.start_pos, element.end_pos)
            else
              result << Harpnotes::Music::Goto.new(element, target, distance: argument) #todo: better algorithm
            end

            result
          end
        else
          nil
        end
      end

      def _make_notebound_annotations(entity)
        result = []
        if entity.is_a? Harpnotes::Music::Playable
          chords =_extract_chord_lines(entity.origin[:raw])
          chords.each do |name|

            match = name.match(/^([!#\<\>])([^\@]+)?(\@(\-?[0-9\.]+),(\-?[0-9\.]+))?$/)
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
                when "<"
                  entity.shift = { dir: :left, size: text }
                when ">"
                  entity.shift = { dir: :right, size: text }
                else
                  annotation = nil # it is not an annotation
              end

              if annotation
                notepos  = [pos_x, pos_y].map { |p| p.to_f } if pos_x
                position = notepos || annotation[:pos] || [2, -5] #todo: make default position configurable
                result << Harpnotes::Music::NoteBoundAnnotation.new(entity, { pos: position, text: annotation[:text] })
              end
            else
               $log.error("syntax error in annotation: #{name}")
            end
          end
        end
        result
      end

      # this appends repeates, jumplines, annotations to the resultl
      def _make_repeats_jumps_annotations(result, voice_element)
        @previous_note = result.first # notes.first # save this for repeat lines etc.


        if part_label = @part_table[voice_element[:time].to_s]
          part                       = Harpnotes::Music::NewPart.new(part_label)
          part.origin                = _parse_origin(voice_element)
          part.companion             = result.first
          result.first.first_in_part = true
          result << part
        end

        if @next_note_marks[:repeat_start]
          @repetition_stack << result.first
          @next_note_marks[:repeat_start] = false
        end

        if @next_note_marks[:variant_ending]
          result << Harpnotes::Music::NoteBoundAnnotation.new(result.first, { pos: [4, -2], text: @next_note_marks[:variant_ending] })
          @next_note_marks[:variant_ending] = nil
        end

        # collect chord based targets
        chords = _extract_chord_lines(voice_element)
        chords.select { |chord| chord[0] == ":" }.each do |name|
          @jumptargets[name[1 .. -1]] = result.select { |n| n.is_a? Harpnotes::Music::Playable }.last
        end
      end

      def _push_slur
        @slurstack += 1
      end

      def _pop_slur
        result     = @slurstack
        @slurstack -= 1
        @slurstack = 0 if @slurstack < 0
        result
      end

      def _extract_chord_lines(voice_element)
        chords = voice_element[:a_gch]
        if chords
          result = chords.select { |e| e[:type] = '^' }.map { |e| e[:text] }
        else
          result = []
        end

        result
      end

      def _parse_origin(voice_element)
        { startChar: voice_element[:istart], endChar: voice_element[:iend], raw: voice_element }
      end

      # this parses the slur information from abc2svg
      # every slur has 4 bits
      # so the slurs are parsed by shifting by 4 and masking 4 bits
      def _parse_slur(slurstart)
        startvalue = slurstart
        result     = []
        while startvalue > 0 do
          result.push startvalue & 0xf
          startvalue >>= 4
        end
        result
      end

      # this parses the tuplet_information out of the voice_elmenet
      def _parse_tuplet_info(voice_element)
        if voice_element[:in_tuplet]

          if voice_element[:extra] and voice_element[:extra][:"15"]
            @tuplet_count      = (voice_element[:extra][:"15"][:tuplet_p])
            @tuplet_down_count = @tuplet_count
            tuplet_start       = true
          else
            tuplet_start = nil
          end

          tuplet = @tuplet_count

          if @tuplet_down_count == 1
            @tuplet_count = 1
            tuplet_end    = true
          else
            @tuplet_down_count -= 1
            tuplet_end         = nil
          end
        else
          tuplet       = 1
          tuplet_start = nil
          tuplet_end   = nil
        end
        return tuplet, tuplet_end, tuplet_start
      end


    end
  end # module Input

end # module Harpnotes
