module Musicaljs


  class Instrument

    def initialize(options)
      @instrument = `new Instrument(options)`
      @playing = false
    end

    def play(options, abc_text)
      `self.instrument.play(options, abc_text)`
    end
  end
end