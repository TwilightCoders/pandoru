# Pandora API Client
#
# This module contains the top level API client that is responsible for calling
# the API and returning the results in model format. There is a base API client
# that is useful for lower level programming such as calling methods that aren't
# directly supported by the higher level API client.
#
# The high level API client is what most clients should use and provides API
# calls that map directly to the Pandora API and return model objects with
# mappings from the raw JSON structures to Ruby objects.
#
# For simplicity use a client builder from Pandoru::ClientBuilder to create an
# instance of a client.

module Pandoru
  module Client
    # Base Pandora API Client
    # The base API client has lower level methods that are composed together to
    # provide higher level functionality.
    class BaseAPIClient
      LOW_AUDIO_QUALITY = "lowQuality"
      MED_AUDIO_QUALITY = "mediumQuality"
      HIGH_AUDIO_QUALITY = "highQuality"

      ALL_QUALITIES = [LOW_AUDIO_QUALITY, MED_AUDIO_QUALITY, HIGH_AUDIO_QUALITY].freeze

      attr_reader :transport, :partner_user, :partner_password, :device, :default_audio_quality
      attr_accessor :username, :password

      def initialize(transport, partner_user = nil, partner_password = nil, device = nil, default_audio_quality: MED_AUDIO_QUALITY)
        @transport = transport
        @partner_user = partner_user
        @partner_password = partner_password
        @device = device
        @default_audio_quality = default_audio_quality
        @username = nil
        @password = nil
      end

      def login(username, password)
        @username = username
        @password = password
        authenticate
      end

      def call(method, **kwargs)
        begin
          @transport.call(method, **kwargs)
        rescue Errors::InvalidAuthToken
          authenticate
          @transport.call(method, **kwargs)
        end
      end

      def self.get_qualities(start_at, return_all_if_invalid: true)
        begin
          idx = ALL_QUALITIES.index(start_at)
          ALL_QUALITIES[0..idx]
        rescue ArgumentError
          return_all_if_invalid ? ALL_QUALITIES.dup : []
        end
      end

      private

      def partner_login
        partner = @transport.call(
          "auth.partnerLogin",
          username: @partner_user,
          password: @partner_password,
          deviceModel: @device,
          version: @transport.class::API_VERSION
        )

        @transport.set_partner(partner)
        partner
      end

      def authenticate
        partner_login

        user = @transport.call(
          "auth.userLogin",
          loginType: "user",
          username: @username,
          password: @password,
          includePandoraOneInfo: true,
          includeSubscriptionExpiration: true,
          returnCapped: true,
          includeAdAttributes: true,
          includeAdvertiserAttributes: true,
          xplatformAdCapable: true
        )

        @transport.set_user(user)
        user
      rescue Errors::InvalidPartnerLogin => e
        raise Errors::InvalidUserLogin.new(e.message)
      end
    end

    # High Level Pandora API Client
    # The high level API client implements the entire functional API for Pandora.
    # This is what clients should actually use.
    class APIClient < BaseAPIClient
      def get_station_list
        data = call("user.getStationList", includeStationArtUrl: true)
        Models::StationList.from_json(self, data)
      end

      def get_station_list_checksum
        data = call("user.getStationListChecksum")
        data["checksum"]
      end

      def get_playlist(station_token, additional_urls: nil)
        params = { 
          stationToken: station_token,
          includeTrackLength: true,
          xplatformAdCapable: true,
          audioAdPodCapable: true
        }
        
        if additional_urls
          urls = additional_urls.map { |url| url.respond_to?(:value) ? url.value : url }
          params[:additionalAudioUrl] = urls.join(",")
        end
        
        data = call("station.getPlaylist", **params)
        
        # Add additional URLs parameter to each item for ad processing
        if additional_urls
          data["items"]&.each { |item| item["_paramAdditionalUrls"] = additional_urls }
        end
        
        playlist = Models::Playlist.from_json(self, data)
        
        # Process ad items
        playlist.each_with_index do |track, i|
          if track.is_ad?
            ad_track = get_ad_item(station_token, track.ad_token)
            playlist[i] = ad_track
          end
        end
        
        playlist
      end

      def get_bookmarks
        data = call("user.getBookmarks")
        Models::BookmarkList.from_json(self, data)
      end

      def get_station(station_token)
        data = call("station.getStation", 
                   stationToken: station_token,
                   includeExtendedAttributes: true)
        Models::Station.from_json(self, data)
      end

      def add_artist_bookmark(track_token)
        call("bookmark.addArtistBookmark", trackToken: track_token)
      end

      def add_song_bookmark(track_token)
        call("bookmark.addSongBookmark", trackToken: track_token)
      end

      def delete_song_bookmark(bookmark_token)
        call("bookmark.deleteSongBookmark", bookmarkToken: bookmark_token)
      end

      def delete_artist_bookmark(bookmark_token)
        call("bookmark.deleteArtistBookmark", bookmarkToken: bookmark_token)
      end

      def search(search_text, include_near_matches: false, include_genre_stations: false)
        data = call("music.search",
                   searchText: search_text,
                   includeNearMatches: include_near_matches,
                   includeGenreStations: include_genre_stations)
        Models::SearchResult.from_json(self, data)
      end

      def add_feedback(track_token, positive)
        call("station.addFeedback",
             trackToken: track_token,
             isPositive: positive)
      end

      def add_music(music_token, station_token)
        call("station.addMusic",
             musicToken: music_token,
             stationToken: station_token)
      end

      def create_station(search_token: nil, artist_token: nil, track_token: nil, song_token: nil)
        params = {}
        
        if search_token
          params[:musicToken] = search_token
        elsif artist_token
          params[:musicToken] = artist_token
        elsif track_token
          params[:musicToken] = track_token  
        elsif song_token
          params[:musicToken] = song_token
        else
          raise ArgumentError, "Must provide one of: search_token, artist_token, track_token, song_token"
        end

        data = call("station.createStation", **params)
        Models::Station.from_json(self, data)
      end

      def delete_feedback(feedback_id)
        call("station.deleteFeedback", feedbackId: feedback_id)
      end

      def delete_music(seed_id)
        call("station.deleteMusic", seedId: seed_id)
      end

      def delete_station(station_token)
        call("station.deleteStation", stationToken: station_token)
      end

      def get_genre_stations
        data = call("station.getGenreStations")
        Models::GenreStationList.from_json(self, data)
      end

      def get_genre_stations_checksum
        data = call("station.getGenreStationsChecksum")
        data["checksum"]
      end

      def rename_station(station_token, name)
        call("station.renameStation",
             stationToken: station_token,
             stationName: name)
      end

      def explain_track(track_token)
        call("track.explainTrack", trackToken: track_token)
      end

      def set_quick_mix(*station_ids)
        call("user.setQuickMix", quickMixStationIds: station_ids.flatten)
      end

      def sleep_song(track_token)
        call("user.sleepSong", trackToken: track_token)
      end

      def share_station(station_id, station_token, *emails)
        call("station.shareStation",
             stationId: station_id,
             stationToken: station_token,
             emails: emails.flatten)
      end

      def transform_shared_station(station_token)
        call("station.transformSharedStation", stationToken: station_token)
      end

      def share_music(music_token, *emails)
        call("music.shareMusic",
             musicToken: music_token,
             emails: emails.flatten)
      end

      def get_ad_item(station_id, ad_token)
        raise Errors::ParameterMissing, "station_id must be defined, got: '#{station_id}'" if station_id.nil? || station_id.empty?
        
        ad_data = get_ad_metadata(ad_token)
        ad_item = Models::AdItem.from_json(self, ad_data)
        ad_item.station_id = station_id
        ad_item.ad_token = ad_token
        ad_item
      end

      def get_ad_metadata(ad_token)
        call("ad.getAdMetadata",
             adToken: ad_token,
             returnAdTrackingTokens: true,
             supportAudioAds: true)
      end

      def register_ad(station_id, tokens)
        call("ad.registerAd",
             stationId: station_id,
             adTrackingTokens: tokens)
      end
    end
  end
end
