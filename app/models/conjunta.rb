class Conjunta < ApplicationRecord
  include Accountable

  class << self
    def color
      "#F59E0B"
    end

    def icon
      "users"
    end

    def classification
      "asset"
    end
  end
end
