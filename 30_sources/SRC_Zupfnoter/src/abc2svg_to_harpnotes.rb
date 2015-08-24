require "native"

module Harpnotes
  # the input faciities, basically the ABCinput stuff.

  module Input

    class Abc2svgToHarpnotes < AbstractAbcToHarpnotes

      def initialize
        super
        @abc_code          = nil
        @previous_new_part = []
      end

      # @param [String] zupfnoter_abc to be transformed
      #
      # @return [Harpnotes::Music::Song] the Song
      def transform(zupfnoter_abc)
        @abc_code   = zupfnoter_abc
        transformer = ABC2SVG::Abc2Svg.new(nil, { mode: :model }) # first argument is the container for SVG
        @abc_model  = transformer.get_abcmodel(zupfnoter_abc)

        result = _transform_voices

        result.meta_data         = {}
        result.meta_data[:tempo] = { duration: [0.25], bpm: 120 }
        result.harpnote_options  = { lyrics: {} }

        result
      end

      private


      def _transform_voices
        hn_voices = @abc_model[:voices].map do |voice_model|

          result = voice_model[:symbols].map do |voice_model_element|
            type = @abc_model[:music_types][voice_model_element[:type]]
            begin
              result = self.send("_transform_#{type}", voice_model_element)
            rescue
              $log.error("BUG: symbol type #{type} not implemented", charpos_to_line_column(voice_model_element[:istart]))
              nil
            end
            result
          end

          result
        end

        hn_voices.unshift(hn_voices.first) # let voice-index start with 1 -> duplicate voice 0
        Harpnotes::Music::Song.new(hn_voices)
      end

      def _transform_bar(voice_element)
        $log.error "bar not implemented"
        nil
      end

      def _transform_note(voice_element)

        abc2svg_duration_factor = 1536

        start_pos = voice_element[:istart]
        end_pos   = voice_element[:iend]

        notes = voice_element[:notes].map do |the_note|
          midi_pitch = the_note[:midi_pitch] # + 49
          duration   = ((the_note[:dur]/abc2svg_duration_factor) * $conf.get('layout.SHORTEST_NOTE')).round

          result           = Harpnotes::Music::Note.new(midi_pitch, duration)
          result.origin    = { startChar: start_pos, endChar: end_pos }
          result.start_pos = charpos_to_line_column(start_pos) # get column und line number of abc_code
          result.end_pos   = charpos_to_line_column(end_pos)

          result
        end

        result          = Harpnotes::Music::SynchPoint.new(notes)
        result.duration = notes.first.duration
        result.origin   = notes.first.origin
        result
      end


    end
  end

end
