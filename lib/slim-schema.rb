module Microdata
  class Thing
    attr_reader :description, :image, :name, :url
  end
  class Person < Thing
    # attr_reader :address, :affiliation, :alumniOf
  end
end