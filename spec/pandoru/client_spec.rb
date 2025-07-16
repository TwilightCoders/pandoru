require 'spec_helper'
require 'webmock/rspec'

RSpec.describe Pandoru::APIClient do
  let(:transport) { instance_double(Pandoru::APITransport) }
  let(:client) { described_class.new(transport) }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after do
    WebMock.reset!
  end

  describe '#initialize' do
    it 'sets transport' do
      expect(client.transport).to eq(transport)
    end
  end

  describe '#login' do
    let(:login_response) do
      {
        'stat' => 'ok',
        'result' => {
          'userId' => 'user123',
          'userAuthToken' => 'auth_token_123'
        }
      }
    end

    let(:partner_response) do
      {
        'stat' => 'ok',
        'result' => {
          'partnerId' => 'partner123',
          'partnerAuthToken' => 'partner_token_123'
        }
      }
    end

    before do
      # Mock partner login call
      allow(transport).to receive(:call)
        .with('auth.partnerLogin', hash_including(username: nil, password: nil, deviceModel: nil))
        .and_return(partner_response)
      
      # Mock user login call  
      allow(transport).to receive(:call)
        .with('auth.userLogin', hash_including(loginType: 'user', username: 'testuser', password: 'testpass'))
        .and_return(login_response)
        
      # Mock transport setter methods
      allow(transport).to receive(:set_partner)
      allow(transport).to receive(:set_user)
    end

    it 'calls transport with correct parameters' do
      client.login('testuser', 'testpass')
      
      expect(transport).to have_received(:call).with('auth.partnerLogin', hash_including(username: nil, password: nil, deviceModel: nil))
      expect(transport).to have_received(:call).with('auth.userLogin', hash_including(loginType: 'user', username: 'testuser', password: 'testpass'))
    end

    it 'returns login response' do
      result = client.login('testuser', 'testpass')
      expect(result).to eq(login_response)
    end
  end

  describe '#get_station_list' do
    let(:station_list_response) do
      {
        'stat' => 'ok',
        'result' => {
          'stations' => [
            {
              'stationId' => 'station1',
              'stationName' => 'Test Station 1',
              'isCreator' => true
            },
            {
              'stationId' => 'station2', 
              'stationName' => 'Test Station 2',
              'isCreator' => false
            }
          ]
        }
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('user.getStationList', includeStationArtUrl: true)
        .and_return(station_list_response)
    end

    it 'calls transport with correct method' do
      client.get_station_list
      
      expect(transport).to have_received(:call).with('user.getStationList', includeStationArtUrl: true)
    end

    it 'returns station list' do
      result = client.get_station_list
      expect(result).to be_a(Pandoru::Models::StationList)
    end
  end

  describe '#get_playlist' do
    let(:playlist_response) do
      {
        'stat' => 'ok',
        'result' => {
          'items' => [
            {
              'trackToken' => 'track1',
              'artistName' => 'Test Artist',
              'songName' => 'Test Song'
            }
          ]
        }
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('station.getPlaylist', hash_including(
          stationToken: 'station123',
          includeTrackLength: true,
          xplatformAdCapable: true,
          audioAdPodCapable: true
        ))
        .and_return(playlist_response)
    end

    it 'calls transport with correct parameters' do
      client.get_playlist('station123')
      
      expect(transport).to have_received(:call).with('station.getPlaylist', hash_including(
        stationToken: 'station123',
        includeTrackLength: true,
        xplatformAdCapable: true,
        audioAdPodCapable: true
      ))
    end

    it 'returns playlist' do
      result = client.get_playlist('station123')
      expect(result).to be_a(Pandoru::Models::Playlist)
    end
  end

  describe '#search' do
    let(:search_response) do
      {
        'stat' => 'ok',
        'result' => {
          'songs' => [
            {
              'artistName' => 'Test Artist',
              'songName' => 'Test Song',
              'musicToken' => 'music123'
            }
          ],
          'artists' => [
            {
              'artistName' => 'Test Artist',
              'musicToken' => 'artist123'
            }
          ]
        }
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('music.search', hash_including(
          searchText: 'test query',
          includeNearMatches: false,
          includeGenreStations: false
        ))
        .and_return(search_response)
    end

    it 'calls transport with correct parameters' do
      client.search('test query')
      
      expect(transport).to have_received(:call).with('music.search', hash_including(
        searchText: 'test query',
        includeNearMatches: false,
        includeGenreStations: false
      ))
    end

    it 'returns search results' do
      result = client.search('test query')
      expect(result).to be_a(Pandoru::Models::SearchResult)
    end
  end

  describe '#create_station' do
    let(:create_station_response) do
      {
        'stat' => 'ok',
        'result' => {
          'stationId' => 'new_station123',
          'stationToken' => 'new_token123'
        }
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('station.createStation', hash_including(
          musicToken: 'music123'
        ))
        .and_return(create_station_response)
    end

    it 'calls transport with correct parameters' do
      client.create_station(search_token: 'music123')
      
      expect(transport).to have_received(:call).with('station.createStation', hash_including(
        musicToken: 'music123'
      ))
    end

    it 'returns station creation result' do
      result = client.create_station(search_token: 'music123')
      expect(result).to be_a(Pandoru::Models::Station)
    end
  end

  describe '#add_feedback' do
    let(:feedback_response) do
      {
        'stat' => 'ok',
        'result' => {}
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('station.addFeedback', hash_including(
          trackToken: 'track123',
          isPositive: true
        ))
        .and_return(feedback_response)
    end

    it 'calls transport with correct parameters for positive feedback' do
      client.add_feedback('track123', true)
      
      expect(transport).to have_received(:call).with('station.addFeedback', hash_including(
        trackToken: 'track123',
        isPositive: true
      ))
    end

    it 'returns feedback result' do
      result = client.add_feedback('track123', true)
      expect(result).to be_a(Hash)
      expect(result).to have_key('stat')
    end
  end

  describe '#delete_station' do
    let(:delete_response) do
      {
        'stat' => 'ok',
        'result' => {}
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('station.deleteStation', hash_including(
          stationToken: 'station123'
        ))
        .and_return(delete_response)
    end

    it 'calls transport with correct parameters' do
      client.delete_station('station123')
      
      expect(transport).to have_received(:call).with('station.deleteStation', hash_including(
        stationToken: 'station123'
      ))
    end

    it 'returns deletion result' do
      result = client.delete_station('station123')
      expect(result).to be_a(Hash)
      expect(result).to have_key('stat')
    end
  end

  describe '#get_bookmarks' do
    let(:bookmarks_response) do
      {
        'stat' => 'ok',
        'result' => {
          'songs' => [
            {
              'artistName' => 'Bookmarked Artist',
              'songName' => 'Bookmarked Song',
              'bookmarkToken' => 'bookmark123'
            }
          ]
        }
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('user.getBookmarks')
        .and_return(bookmarks_response)
    end

    it 'calls transport with correct method' do
      client.get_bookmarks
      
      expect(transport).to have_received(:call).with('user.getBookmarks')
    end

    it 'returns bookmarks' do
      result = client.get_bookmarks
      expect(result).to be_a(Pandoru::Models::BookmarkList)
    end
  end

  describe '#add_artist_bookmark' do
    let(:add_bookmark_response) do
      {
        'stat' => 'ok',
        'result' => {
          'bookmarkToken' => 'new_bookmark123'
        }
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('bookmark.addArtistBookmark', hash_including(
          trackToken: 'track123'
        ))
        .and_return(add_bookmark_response)
    end

    it 'calls transport with correct parameters' do
      client.add_artist_bookmark('track123')
      
      expect(transport).to have_received(:call).with('bookmark.addArtistBookmark', hash_including(
        trackToken: 'track123'
      ))
    end

    it 'returns bookmark creation result' do
      result = client.add_artist_bookmark('track123')
      expect(result).to be_a(Hash)
      expect(result).to have_key('stat')
    end
  end

  describe '#get_genre_stations' do
    let(:genre_stations_response) do
      {
        'stat' => 'ok',
        'result' => {
          'categories' => [
            {
              'categoryName' => 'Rock',
              'stations' => [
                {
                  'stationId' => 'genre_rock',
                  'stationName' => 'Classic Rock'
                }
              ]
            }
          ]
        }
      }
    end

    before do
      allow(transport).to receive(:call)
        .with('station.getGenreStations')
        .and_return(genre_stations_response)
    end

    it 'calls transport with correct method' do
      client.get_genre_stations
      
      expect(transport).to have_received(:call).with('station.getGenreStations')
    end

    it 'returns genre stations' do
      result = client.get_genre_stations
      expect(result).to be_a(Pandoru::Models::GenreStationList)
    end
  end

  describe 'error handling' do
    before do
      allow(transport).to receive(:call)
        .and_raise(Pandoru::APIError.new('Test error'))
    end

    it 'propagates transport errors' do
      expect {
        client.login('user', 'pass')
      }.to raise_error(Pandoru::APIError, 'Test error')
    end
  end
end
