require_relative '_base'

module Pandoru
  module Models
    class PlaylistItem < Base
      field :track_token, "trackToken"
      field :artist_name, "artistName"
      field :album_name, "albumName"
      field :song_name, "songName"
      field :song_rating, "songRating"
      field :track_length, "trackLength"
      field :allow_feedback, "allowFeedback", type: :boolean
      field :ad_token, "adToken"
      field :audio_url_map, "audioUrlMap"
      field :is_ad, "isAd", type: :boolean

      def initialize(data = {}, api_client = nil)
        super(data, api_client)
      end

      def is_ad?
        @is_ad || false
      end

      def audio_url(quality = nil)
        return nil unless @audio_url_map
        
        quality ||= @api_client&.default_audio_quality || "mediumQuality"
        @audio_url_map[quality]
      end

      def thumbs_up
        return unless @api_client && @allow_feedback
        @api_client.add_feedback(@track_token, true)
      end

      def thumbs_down
        return unless @api_client && @allow_feedback
        @api_client.add_feedback(@track_token, false)
      end

      def bookmark_song
        return unless @api_client
        @api_client.add_song_bookmark(@track_token)
      end

      def bookmark_artist
        return unless @api_client
        @api_client.add_artist_bookmark(@track_token)
      end

      def sleep
        return unless @api_client
        @api_client.sleep_song(@track_token)
      end
    end

    class Playlist < Collection
      def self.from_json(api_client, data)
        playlist = new({}, api_client)
        playlist.populate_from_json(data)
        
        # Add playlist items
        if data["items"]
          data["items"].each do |item_data|
            item = PlaylistItem.from_json(api_client, item_data)
            playlist << item
          end
        end
        
        playlist
      end
    end

    class AdItem < PlaylistItem
      field :ad_token, "adToken"
      field :company_name, "companyName"
      field :title, "title"
      field :click_through_url, "clickThroughUrl"
      field :image_url, "imageUrl"
      field :tracking_tokens, "trackingTokens"

      attr_accessor :station_id

      def initialize(data = {}, api_client = nil)
        super(data, api_client)
        @is_ad = true
      end
    end
  end
end