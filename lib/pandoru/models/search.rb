require_relative '_base'

module Pandoru
  module Models
    class SearchResultItem < Base
      field :artist_name, 'artistName'
      field :song_name, 'songName'
      field :music_token, 'musicToken'
      field :score, 'score'
      field :likely_match, 'likelyMatch', type: :boolean

      def song?
        !song_name.nil?
      end

      def artist?
        song_name.nil?
      end

      def create_station
        return nil unless @api_client
        if song?
          @api_client.create_station(song_token: music_token)
        else
          @api_client.create_station(artist_token: music_token)
        end
      end
    end

    class SearchResult < Collection
      field :near_matches_available, 'nearMatchesAvailable', type: :boolean
      field :explanation, 'explanation'

      def self.from_json(api_client, data)
        instance = new(data, api_client)
        instance.populate_from_json(data)
        
        # Add songs
        if data['songs']
          SearchResultItem.from_json_list(api_client, data['songs']).each do |item|
            instance << item
          end
        end

        # Add artists (convert to SearchResultItem format)
        if data['artists']
          data['artists'].each do |artist_data|
            item_data = {
              'artistName' => artist_data['artistName'],
              'musicToken' => artist_data['musicToken'],
              'score' => artist_data['score'],
              'likelyMatch' => artist_data['likelyMatch']
            }
            item = SearchResultItem.from_json(api_client, item_data)
            instance << item
          end
        end

        instance
      end

      def songs
        select(&:song?)
      end

      def artists
        select(&:artist?)
      end

      def best_match
        max_by(&:score)
      end
    end
  end
end
