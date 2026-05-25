require_relative 'models/_base'
require_relative 'models/station'
require_relative 'models/playlist'
require_relative 'models/search'
require_relative 'models/bookmark'
require_relative 'models/track_explanation'

module Pandoru
  module Models
    # Convenience method to create models from API responses
    def self.from_json(model_class, data, api_client = nil)
      model_class.from_json(data, api_client)
    end

    def self.from_json_list(model_class, data_list, api_client = nil)
      model_class.from_json_list(data_list, api_client)
    end
  end
end
