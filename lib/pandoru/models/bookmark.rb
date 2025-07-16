require_relative '_base'

module Pandoru
  module Models
    class Bookmark < Base
      field :bookmark_token, 'bookmarkToken'
      field :music_token, 'musicToken'
      field :artist_name, 'artistName'
      field :song_name, 'songName'
      field :art_url, 'artUrl'
      field :sample_url, 'sampleUrl'
      field :sample_gain, 'sampleGain'
      field :album_name, 'albumName'
      date_field :date_created, 'dateCreated'

      def song_bookmark?
        !song_name.nil?
      end

      def artist_bookmark?
        song_name.nil?
      end

      def delete
        return false unless @api_client
        if song_bookmark?
          @api_client.delete_song_bookmark(bookmark_token)
        else
          @api_client.delete_artist_bookmark(bookmark_token)
        end
        true
      end
    end

    class BookmarkList < Collection
      def self.from_json(data, api_client = nil)
        instance = new(data, api_client)
        
        # Add song bookmarks
        if data['songs']
          Bookmark.from_json_list(data['songs'], api_client).each do |bookmark|
            instance << bookmark
          end
        end

        # Add artist bookmarks (ensure song_name is nil for artists)
        if data['artists']
          data['artists'].each do |artist_data|
            artist_data['songName'] = nil unless artist_data.key?('songName')
            bookmark = Bookmark.from_json(artist_data, api_client)
            instance << bookmark
          end
        end

        instance
      end

      def song_bookmarks
        select(&:song_bookmark?)
      end

      def artist_bookmarks
        select(&:artist_bookmark?)
      end

      def find_song_bookmark(song_name, artist_name = nil)
        song_bookmarks.find do |bookmark|
          matches_song = bookmark.song_name&.casecmp(song_name) == 0
          matches_artist = artist_name.nil? || bookmark.artist_name&.casecmp(artist_name) == 0
          matches_song && matches_artist
        end
      end

      def find_artist_bookmark(artist_name)
        artist_bookmarks.find do |bookmark|
          bookmark.artist_name&.casecmp(artist_name) == 0
        end
      end
    end
  end
end
