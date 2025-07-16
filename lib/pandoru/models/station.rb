require_relative '_base'

module Pandoru
  module Models
    class Station < Base
      field :station_id, 'stationId'
      field :station_name, 'stationName' 
      field :station_token, 'stationToken'
      field :art_url, 'artUrl'
      field :detail_url, 'stationDetailUrl'
      field :sharing_url, 'stationSharingUrl'
      
      field :allow_add_music, 'allowAddMusic', type: :boolean
      field :allow_delete, 'allowDelete', type: :boolean
      field :allow_rename, 'allowRename', type: :boolean
      field :allow_edit_description, 'allowEditDescription', type: :boolean
      
      field :is_creator, 'isCreator', type: :boolean
      field :is_shared, 'isShared', type: :boolean
      field :is_quickmix, 'isQuickMix', type: :boolean
      field :is_genre_station, 'isGenreStation', type: :boolean
      field :is_thumbprint, 'isThumbprint', type: :boolean
      
      field :thumb_count, 'thumbCount'
      date_field :date_created, 'dateCreated'

      # Convenience aliases
      alias_method :id, :station_id
      alias_method :name, :station_name
      alias_method :token, :station_token

      def get_playlist
        return nil unless @api_client
        @api_client.get_playlist(token)
      end

      def rename(new_name)
        return false unless allow_rename && @api_client
        @api_client.rename_station(token, new_name)
        @name = new_name
        true
      end

      def delete
        return false unless allow_delete && @api_client
        @api_client.delete_station(token)
        true
      end

      def add_seed(music_token)
        return false unless allow_add_music && @api_client
        @api_client.add_music(token, music_token)
        true
      end
    end

    class StationList < Collection
      field :checksum, 'checksum'

      def self.from_json(api_client, data)
        instance = new(data, api_client)
        instance.populate_from_json(data)
        
        if data['stations']
          stations = Station.from_json_list(api_client, data['stations'])
          stations.each { |station| instance << station }
        end
        
        instance
      end

      def find_by_name(name)
        find { |station| station.name == name }
      end

      def quickmix_stations
        select(&:is_quickmix)
      end

      def user_stations
        reject(&:is_quickmix)
      end
    end

    class GenreStation < Base
      field :id, 'stationId'
      field :name, 'stationName'
      field :token, 'stationToken'
      field :category, 'categoryName'

      def create_station
        return nil unless @api_client
        @api_client.create_station(search_token: token)
      end
    end

    class GenreStationList < Collection
      field :checksum, 'checksum'

      def self.from_json(api_client, data)
        instance = new(data, api_client)
        instance.populate_from_json(data)
        
        if data['categories']
          data['categories'].each do |category|
            category_name = category['categoryName']
            next unless category['stations']
            
            category['stations'].each do |station_data|
              station_data['categoryName'] = category_name
              station = GenreStation.from_json(api_client, station_data)
              instance << station
            end
          end
        end
        
        instance
      end

      def categories
        map(&:category).uniq
      end

      def stations_for_category(category)
        select { |station| station.category == category }
      end
    end
  end
end
