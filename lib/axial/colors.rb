module Axial
  # class methods to get IRC color codes
  class Colors
    @reset        = "\x03".freeze
    @white        = @reset + '1'
    @darkblue     = @reset + '2'
    @darkgreen    = @reset + '3'
    @red          = @reset + '4'
    @darkred      = @reset + '5'
    @darkmagenta  = @reset + '6'
    @orange       = @reset + '7'
    @yellow       = @reset + '8'
    @green        = @reset + '9'
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
