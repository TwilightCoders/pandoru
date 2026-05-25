require_relative '_base'

module Pandoru
  module Models
    # A single station seed — an artist, song, or genre the station was
    # built from. Returned under the "music" key of a getStation response
    # when includeExtendedAttributes is set.
    class StationSeed < Base
      field :seed_id, 'seedId'
      field :music_token, 'musicToken'
      field :pandora_id, 'pandoraId'
      field :pandora_type, 'pandoraType'
      field :genre_name, 'genreName'
      field :song_name, 'songName'
      field :artist_name, 'artistName'
      field :art_url, 'artUrl'

      def song?
        !song_name.nil?
      end

      def artist?
        song_name.nil? && !artist_name.nil?
      end

      def genre?
        !genre_name.nil?
      end

      # Human-readable label, handy for clustering/debugging.
      def label
        return genre_name if genre?
        [artist_name, song_name].compact.join(' - ')
      end
    end

    # The seed sets for a station, grouped by kind.
    class StationSeeds < Base
      attr_accessor :genres, :songs, :artists

      def self.from_json(api_client, data)
        return nil unless data
        instance = new(data, api_client)
        instance.genres  = StationSeed.from_json_list(api_client, data['genres'])
        instance.songs   = StationSeed.from_json_list(api_client, data['songs'])
        instance.artists = StationSeed.from_json_list(api_client, data['artists'])
        instance
      end

      # All seeds flattened into one array.
      def all
        Array(genres) + Array(artists) + Array(songs)
      end
    end

    # A single thumbs-up/down on a song.
    class SongFeedback < Base
      field :feedback_id, 'feedbackId'
      field :song_identity, 'songIdentity'
      field :is_positive, 'isPositive', type: :boolean
      field :pandora_id, 'pandoraId'
      field :album_art_url, 'albumArtUrl'
      field :music_token, 'musicToken'
      field :song_name, 'songName'
      field :artist_name, 'artistName'
      field :pandora_type, 'pandoraType'
      date_field :date_created, 'dateCreated'

      def positive?
        is_positive == true
      end
    end

    # A station's feedback (thumbs) returned under the "feedback" key of an
    # extended getStation response.
    class StationFeedback < Base
      attr_accessor :thumbs_up, :thumbs_down
      field :total_thumbs_up, 'totalThumbsUp'
      field :total_thumbs_down, 'totalThumbsDown'

      def self.from_json(api_client, data)
        return nil unless data
        instance = new(data, api_client)
        instance.populate_from_json(data)
        instance.thumbs_up   = SongFeedback.from_json_list(api_client, data['thumbsUp'])
        instance.thumbs_down = SongFeedback.from_json_list(api_client, data['thumbsDown'])
        instance
      end
    end

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

      # Populated only by getStation with includeExtendedAttributes; nil for
      # stations returned in a getStationList response.
      attr_accessor :seeds, :feedback

      # Convenience aliases
      alias_method :id, :station_id
      alias_method :name, :station_name
      alias_method :token, :station_token

      def self.from_json(api_client, data)
        station = super
        return station unless station && data
        station.seeds    = StationSeeds.from_json(api_client, data['music'])
        station.feedback = StationFeedback.from_json(api_client, data['feedback'])
        station
      end

      # Seed accessors that are always safe to call (empty array when the
      # station was loaded without extended attributes).
      def seed_artists
        seeds&.artists || []
      end

      def seed_songs
        seeds&.songs || []
      end

      def seed_genres
        seeds&.genres || []
      end

      def thumbs_up
        feedback&.thumbs_up || []
      end

      def thumbs_down
        feedback&.thumbs_down || []
      end

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
        # add_music expects (music_token, station_token) — music token first.
        @api_client.add_music(music_token, token)
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
