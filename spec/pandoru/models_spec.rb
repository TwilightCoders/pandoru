require 'spec_helper'

RSpec.describe Pandoru::Models::PandoraModel do
  # Create a test model class for testing
  let(:test_model_class) do
    Class.new(described_class) do
      field :name, 'stationName'
      field :id, 'stationId'
      field :creator, 'isCreator'
      date_field :creation_date, 'dateCreated'
      field :token, 'stationToken'
    end
  end
  
  let(:sample_data) do
    {
      'stationName' => 'Test Station',
      'stationId' => 'station123',
      'isCreator' => true,
      'dateCreated' => {
        'time' => 1640995200000  # 2022-01-01 00:00:00 UTC in milliseconds
      },
      'stationToken' => 'token123'
    }
  end

  let(:mock_api_client) { double('APIClient') }

  describe '.field' do
    it 'defines field mappings' do
      expect(test_model_class.fields).to include(:name, :id, :creator, :creation_date, :token)
    end

    it 'creates accessor methods' do
      instance = test_model_class.new(mock_api_client)
      
      expect(instance).to respond_to(:name)
      expect(instance).to respond_to(:id)
      expect(instance).to respond_to(:creator)
      expect(instance).to respond_to(:creation_date)
      expect(instance).to respond_to(:token)
    end
  end

  describe '.from_json' do
    it 'creates instance from JSON data' do
      instance = test_model_class.from_json(mock_api_client, sample_data)
      
      expect(instance.name).to eq('Test Station')
      expect(instance.id).to eq('station123')
      expect(instance.creator).to eq(true)
      expect(instance.token).to eq('token123')
    end

    it 'handles date fields correctly' do
      instance = test_model_class.from_json(mock_api_client, sample_data)
      expect(instance.creation_date).to be_a(Time)
      expect(instance.creation_date.year).to eq(2022)
      expect(instance.creation_date.month).to eq(1)
      expect(instance.creation_date.day).to eq(1)
    end

    it 'handles missing date fields' do
      data_without_date = sample_data.dup
      data_without_date.delete('dateCreated')
      
      instance = test_model_class.from_json(mock_api_client, data_without_date)
      expect(instance.creation_date).to be_nil
    end

    it 'handles nil data gracefully' do
      instance = test_model_class.from_json(mock_api_client, nil)
      expect(instance).to be_nil
    end
  end

  describe '.from_json_list' do
    it 'creates array of instances from array of JSON data' do
      data_array = [sample_data, sample_data.merge('stationName' => 'Another Station')]
      
      instances = test_model_class.from_json_list(mock_api_client, data_array)
      
      expect(instances).to be_an(Array)
      expect(instances.length).to eq(2)
      expect(instances.first.name).to eq('Test Station')
      expect(instances.last.name).to eq('Another Station')
    end

    it 'handles empty arrays' do
      instances = test_model_class.from_json_list(mock_api_client, [])
      expect(instances).to eq([])
    end

    it 'handles nil data' do
      instances = test_model_class.from_json_list(mock_api_client, nil)
      expect(instances).to eq([])
    end
  end

  describe '#initialize' do
    it 'sets default values for fields' do
      instance = test_model_class.new(mock_api_client)
      
      expect(instance.name).to be_nil
      expect(instance.id).to be_nil
      expect(instance.creator).to be_nil
      expect(instance.token).to be_nil
    end
  end
end

RSpec.describe Pandoru::Models::Station do
  let(:mock_api_client) { double('APIClient') }
  
  let(:station_data) do
    {
      'stationName' => 'My Test Station',
      'stationId' => 'station456',
      'stationToken' => 'token456',
      'isCreator' => true,
      'dateCreated' => {
        'time' => 1640995200000
      },
      'artUrl' => 'http://example.com/art.jpg'
    }
  end

  describe '.from_json' do
    it 'creates station with basic attributes' do
      station = described_class.from_json(mock_api_client, station_data)
      
      expect(station.station_name).to eq('My Test Station')
      expect(station.station_id).to eq('station456')
      expect(station.station_token).to eq('token456')
      expect(station.is_creator).to eq(true)
      expect(station.art_url).to eq('http://example.com/art.jpg')
    end

    it 'handles date fields' do
      station = described_class.from_json(mock_api_client, station_data)
      expect(station.date_created).to be_a(Time)
    end
  end
end

RSpec.describe Pandoru::Models::PlaylistItem do
  let(:mock_api_client) { double('APIClient') }
  
  let(:playlist_item_data) do
    {
      'trackToken' => 'track789',
      'artistName' => 'Test Artist',
      'albumName' => 'Test Album',
      'songName' => 'Test Song',
      'songRating' => 1,
      'trackLength' => 240,
      'allowFeedback' => true,
      'adToken' => nil
    }
  end

  describe '.from_json' do
    it 'creates playlist item with basic attributes' do
      item = described_class.from_json(mock_api_client, playlist_item_data)
      
      expect(item.track_token).to eq('track789')
      expect(item.artist_name).to eq('Test Artist')
      expect(item.album_name).to eq('Test Album')
      expect(item.song_name).to eq('Test Song')
      expect(item.song_rating).to eq(1)
      expect(item.track_length).to eq(240)
      expect(item.allow_feedback).to eq(true)
      expect(item.ad_token).to be_nil
    end
  end
end

RSpec.describe Pandoru::Models::DateField do
  let(:date_field) { described_class.new('testField') }
  let(:mock_api_client) { double('APIClient') }

  describe '#formatter' do
    it 'converts timestamp to Time object' do
      data = { 'time' => 1640995200000 }
      result = date_field.formatter(mock_api_client, {}, data)
      
      expect(result).to be_a(Time)
      expect(result.year).to eq(2022)
      expect(result.month).to eq(1)
      expect(result.day).to eq(1)
    end

    it 'handles nil data' do
      result = date_field.formatter(mock_api_client, {}, nil)
      expect(result).to be_nil
    end

    it 'handles missing time field' do
      result = date_field.formatter(mock_api_client, {}, {})
      expect(result).to be_nil
    end
  end
end
