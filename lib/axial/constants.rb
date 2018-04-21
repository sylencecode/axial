require 'axial/color'

module Axial
  module Constants
    ACCESS_DENIED     = 'access denied. sorry.' # rubocop:disable Style/MutableConstant
    AXIAL_NAME        = 'axial' # rubocop:disable Style/MutableConstant
    AXIAL_VERSION     = '1.1.0' # rubocop:disable Style/MutableConstant
    AXIAL_AUTHOR      = 'sylence <sylence@sylence.org>' # rubocop:disable Style/MutableConstant
    AXIAL_KICK_LOGO   = '[ax!k]' # rubocop:disable Style/MutableConstant
    AXIAL_LOGO        = Color.gray + 'a' + Color.reset + 'x' + Color.white + 'i' + Color.reset + 'a' + Color.gray + 'l' + Color.reset
  end
end
