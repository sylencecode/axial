module Axial
  # class methods to get IRC color codes
  class Colors
    @reset        = "\x03".freeze
    @white        = @reset + '01'
    @darkblue     = @reset + '02'
    @darkgreen    = @reset + '03'
    @red          = @reset + '04'
    @darkred      = @reset + '05'
    @darkmagenta  = @reset + '06'
    @orange       = @reset + '07'
    @yellow       = @reset + '08'
    @green        = @reset + '09'
    @darkcyan     = @reset + '10'
    @cyan         = @reset + '11'
    @blue         = @reset + '12'
    @magenta      = @reset + '13'
    @gray         = @reset + '14'
    @silver       = @reset + '15'

    class << self
      attr_reader :reset, :white, :darkblue, :darkgreen, :red, :darkred, :darkmagenta,
                  :orange, :yellow, :green, :darkcyan, :cyan, :blue, :magenta, :gray,
                  :silver
    end
  end
end
