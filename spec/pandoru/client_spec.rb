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

    before do
      allow(transport).to receive(:call)
        .with('auth.userLogin', {
          'loginType' => 'user',
          'username' => 'testuser',
          'password' => 'testpass'
        })
        .and_return(login_response)
    end

    it 'calls transport with correct parameters' do
      client.login('testuser', 'testpass')
      
      expect(transport).to have_received(:call).with('auth.userLogin', {
        'loginType' => 'user',
        'username' => 'testuser',
        'password' => 'testpass'
      })
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
        .with('user.getStationList', {})
        .and_return(station_list_response)
    end

    it 'calls transport with correct method' do
      client.get_station_list
      
      expect(transport).to have_received(:call).with('user.getStationList', {})
    end

    it 'returns station list' do
      result = client.get_station_list
      expect(result).to eq(station_list_response)
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
        .with('station.getPlaylist', {
          'stationToken' => 'station123'
        })
        .and_return(playlist_response)
    end

    it 'calls transport with correct parameters' do
      client.get_playlist('station123')
      
      expect(transport).to have_received(:call).with('station.getPlaylist', {
        'stationToken' => 'station123'
      })
    end

    it 'returns playlist' do
      result = client.get_playlist('station123')
      expect(result).to eq(playlist_response)
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
        .with('music.search', {
          'searchText' => 'test query'
        })
        .and_return(search_response)
    end

    it 'calls transport with correct parameters' do
      client.search('test query')
      
      expect(transport).to have_received(:call).with('music.search', {
        'searchText' => 'test query'
      })
    end

    it 'returns search results' do
      result = client.search('test query')
      expect(result).to eq(search_response)
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
        .with('station.createStation', {
          'musicToken' => 'music123',
          'musicType' => 'song'
        })
        .and_return(create_station_response)
    end

    it 'calls transport with correct parameters' do
      client.create_station('music123', 'song')
      
      expect(transport).to have_received(:call).with('station.createStation', {
        'musicToken' => 'music123',
        'musicType' => 'song'
      })
    end

    it 'returns station creation result' do
      result = client.create_station('music123', 'song')
      expect(result).to eq(create_station_response)
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
        .with('station.addFeedback', {
          'trackToken' => 'track123',
          'isPositive' => true
        })
        .and_return(feedback_response)
    end

    it 'calls transport with correct parameters for positive feedback' do
      client.add_feedback('track123', true)
      
      expect(transport).to have_received(:call).with('station.addFeedback', {
        'trackToken' => 'track123',
        'isPositive' => true
      })
    end

    it 'returns feedback result' do
      result = client.add_feedback('track123', true)
      expect(result).to eq(feedback_response)
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
        .with('station.deleteStation', {
          'stationToken' => 'station123'
        })
        .and_return(delete_response)
    end

    it 'calls transport with correct parameters' do
      client.delete_station('station123')
      
      expect(transport).to have_received(:call).with('station.deleteStation', {
        'stationToken' => 'station123'
      })
    end

    it 'returns deletion result' do
      result = client.delete_station('station123')
      expect(result).to eq(delete_response)
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
        .with('user.getBookmarks', {})
        .and_return(bookmarks_response)
    end

    it 'calls transport with correct method' do
      client.get_bookmarks
      
      expect(transport).to have_received(:call).with('user.getBookmarks', {})
    end

    it 'returns bookmarks' do
      result = client.get_bookmarks
      expect(result).to eq(bookmarks_response)
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
        .with('user.createBookmark', {
          'trackToken' => 'track123',
          'type' => 'artist'
        })
        .and_return(add_bookmark_response)
    end

    it 'calls transport with correct parameters' do
      client.add_artist_bookmark('track123')
      
      expect(transport).to have_received(:call).with('user.createBookmark', {
        'trackToken' => 'track123',
        'type' => 'artist'
      })
    end

    it 'returns bookmark creation result' do
      result = client.add_artist_bookmark('track123')
      expect(result).to eq(add_bookmark_response)
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
        .with('station.getGenreStations', {})
        .and_return(genre_stations_response)
    end

    it 'calls transport with correct method' do
      client.get_genre_stations
      
      expect(transport).to have_received(:call).with('station.getGenreStations', {})
    end

    it 'returns genre stations' do
      result = client.get_genre_stations
      expect(result).to eq(genre_stations_response)
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
