require 'spec_helper'

# Exercises the high-level APIClient method wrappers by stubbing the low-level
# #call, so each wrapper's body (method name, params, model mapping) is covered
# without touching the network.
RSpec.describe Pandoru::Client::APIClient do
  let(:transport) { instance_double(Pandoru::APITransport) }
  let(:client) { described_class.new(transport) }

  describe 'fire-and-forget wrappers send the right method + params' do
    it 'add_artist_bookmark' do
      expect(client).to receive(:call).with('bookmark.addArtistBookmark', trackToken: 'tk')
      client.add_artist_bookmark('tk')
    end

    it 'add_song_bookmark' do
      expect(client).to receive(:call).with('bookmark.addSongBookmark', trackToken: 'tk')
      client.add_song_bookmark('tk')
    end

    it 'delete_song_bookmark' do
      expect(client).to receive(:call).with('bookmark.deleteSongBookmark', bookmarkToken: 'bk')
      client.delete_song_bookmark('bk')
    end

    it 'delete_artist_bookmark' do
      expect(client).to receive(:call).with('bookmark.deleteArtistBookmark', bookmarkToken: 'bk')
      client.delete_artist_bookmark('bk')
    end

    it 'add_feedback' do
      expect(client).to receive(:call).with('station.addFeedback', trackToken: 'tk', isPositive: true)
      client.add_feedback('tk', true)
    end

    it 'add_music sends music token first, station token second' do
      expect(client).to receive(:call).with('station.addMusic', musicToken: 'mt', stationToken: 'st')
      client.add_music('mt', 'st')
    end

    it 'delete_feedback' do
      expect(client).to receive(:call).with('station.deleteFeedback', feedbackId: 'fb')
      client.delete_feedback('fb')
    end

    it 'delete_music' do
      expect(client).to receive(:call).with('station.deleteMusic', seedId: 'sd')
      client.delete_music('sd')
    end

    it 'delete_station' do
      expect(client).to receive(:call).with('station.deleteStation', stationToken: 'st')
      client.delete_station('st')
    end

    it 'rename_station' do
      expect(client).to receive(:call).with('station.renameStation', stationToken: 'st', stationName: 'New')
      client.rename_station('st', 'New')
    end

    it 'set_quick_mix flattens station ids' do
      expect(client).to receive(:call).with('user.setQuickMix', quickMixStationIds: %w[a b])
      client.set_quick_mix('a', 'b')
    end

    it 'sleep_song' do
      expect(client).to receive(:call).with('user.sleepSong', trackToken: 'tk')
      client.sleep_song('tk')
    end

    it 'share_station flattens emails' do
      expect(client).to receive(:call).with('station.shareStation', stationId: 'id', stationToken: 'st', emails: %w[a@x b@y])
      client.share_station('id', 'st', 'a@x', 'b@y')
    end

    it 'transform_shared_station' do
      expect(client).to receive(:call).with('station.transformSharedStation', stationToken: 'st')
      client.transform_shared_station('st')
    end

    it 'share_music' do
      expect(client).to receive(:call).with('music.shareMusic', musicToken: 'mt', emails: ['a@x'])
      client.share_music('mt', 'a@x')
    end

    it 'register_ad' do
      expect(client).to receive(:call).with('ad.registerAd', stationId: 'id', adTrackingTokens: %w[t1 t2])
      client.register_ad('id', %w[t1 t2])
    end

    it 'get_station_list_checksum returns the checksum value' do
      allow(client).to receive(:call).with('user.getStationListChecksum').and_return('checksum' => 'abc')
      expect(client.get_station_list_checksum).to eq('abc')
    end

    it 'get_genre_stations_checksum returns the checksum value' do
      allow(client).to receive(:call).with('station.getGenreStationsChecksum').and_return('checksum' => 'xyz')
      expect(client.get_genre_stations_checksum).to eq('xyz')
    end
  end

  describe 'model-returning methods' do
    it 'get_station_list builds a StationList' do
      allow(client).to receive(:call).and_return('stations' => [], 'checksum' => 'c')
      expect(client.get_station_list).to be_a(Pandoru::Models::StationList)
    end

    it 'get_bookmarks builds a BookmarkList' do
      allow(client).to receive(:call).and_return('songs' => [], 'artists' => [])
      expect(client.get_bookmarks).to be_a(Pandoru::Models::BookmarkList)
    end

    it 'get_station builds a Station with extended attributes requested' do
      expect(client).to receive(:call)
        .with('station.getStation', stationToken: 'st', includeExtendedAttributes: true)
        .and_return('stationId' => 'st', 'stationName' => 'S')
      expect(client.get_station('st')).to be_a(Pandoru::Models::Station)
    end

    it 'search builds a SearchResult' do
      expect(client).to receive(:call)
        .with('music.search', searchText: 'metal', includeNearMatches: false, includeGenreStations: false)
        .and_return('songs' => [], 'artists' => [])
      expect(client.search('metal')).to be_a(Pandoru::Models::SearchResult)
    end

    it 'create_station from a search token' do
      expect(client).to receive(:call).with('station.createStation', musicToken: 'mt')
        .and_return('stationId' => 'st')
      expect(client.create_station(search_token: 'mt')).to be_a(Pandoru::Models::Station)
    end

    it 'create_station raises without any token' do
      expect { client.create_station }.to raise_error(ArgumentError)
    end

    it 'get_genre_stations builds a GenreStationList' do
      allow(client).to receive(:call).and_return('categories' => [])
      expect(client.get_genre_stations).to be_a(Pandoru::Models::GenreStationList)
    end

    it 'explain_track builds a TrackExplanation' do
      allow(client).to receive(:call).and_return('explanations' => [])
      expect(client.explain_track('tk')).to be_a(Pandoru::Models::TrackExplanation)
    end

    it 'get_playlist builds a Playlist' do
      allow(client).to receive(:call).and_return('items' => [])
      expect(client.get_playlist('st')).to be_a(Pandoru::Models::Playlist)
    end
  end

  describe '.get_qualities' do
    it 'returns qualities up to and including the start point' do
      expect(described_class.get_qualities('mediumQuality'))
        .to eq(%w[lowQuality mediumQuality])
    end
  end
end
