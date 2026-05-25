require 'spec_helper'

RSpec.describe Pandoru::Models::Bookmark do
  let(:api) { double('APIClient') }

  it 'classifies song vs artist bookmarks' do
    song = described_class.from_json(api, 'songName' => 'One', 'artistName' => 'Metallica')
    artist = described_class.from_json(api, 'artistName' => 'Metallica')
    expect(song).to be_song_bookmark
    expect(artist).to be_artist_bookmark
  end

  describe '#delete' do
    it 'routes song bookmarks to delete_song_bookmark' do
      song = described_class.from_json(api, 'songName' => 'One', 'bookmarkToken' => 'bk')
      expect(api).to receive(:delete_song_bookmark).with('bk')
      expect(song.delete).to eq(true)
    end

    it 'routes artist bookmarks to delete_artist_bookmark' do
      artist = described_class.from_json(api, 'artistName' => 'Metallica', 'bookmarkToken' => 'bk')
      expect(api).to receive(:delete_artist_bookmark).with('bk')
      expect(artist.delete).to eq(true)
    end

    it 'is a no-op without an api client' do
      expect(described_class.from_json(nil, 'songName' => 'x').delete).to eq(false)
    end
  end
end

RSpec.describe Pandoru::Models::BookmarkList do
  let(:data) do
    {
      'songs' => [{ 'songName' => 'One', 'artistName' => 'Metallica', 'bookmarkToken' => 's1' }],
      'artists' => [{ 'artistName' => 'Tool', 'bookmarkToken' => 'a1' }]
    }
  end

  subject(:list) { described_class.from_json(nil, data) }

  it 'splits song and artist bookmarks' do
    expect(list.song_bookmarks.map(&:song_name)).to eq(['One'])
    expect(list.artist_bookmarks.map(&:artist_name)).to eq(['Tool'])
  end

  it 'finds a song bookmark case-insensitively, optionally scoped by artist' do
    expect(list.find_song_bookmark('one')).not_to be_nil
    expect(list.find_song_bookmark('one', 'metallica')).not_to be_nil
    expect(list.find_song_bookmark('one', 'nobody')).to be_nil
  end

  it 'finds an artist bookmark case-insensitively' do
    expect(list.find_artist_bookmark('tool')).not_to be_nil
    expect(list.find_artist_bookmark('missing')).to be_nil
  end
end

RSpec.describe Pandoru::Models::SearchResultItem do
  let(:api) { double('APIClient') }

  it 'create_station uses a song token for songs' do
    item = described_class.from_json(api, 'songName' => 'One', 'musicToken' => 'mt')
    expect(api).to receive(:create_station).with(song_token: 'mt')
    item.create_station
  end

  it 'create_station uses an artist token for artists' do
    item = described_class.from_json(api, 'artistName' => 'Tool', 'musicToken' => 'mt')
    expect(api).to receive(:create_station).with(artist_token: 'mt')
    item.create_station
  end
end

RSpec.describe Pandoru::Models::SearchResult do
  subject(:result) do
    described_class.from_json(nil,
      'nearMatchesAvailable' => true,
      'songs' => [{ 'songName' => 'One', 'score' => 90, 'musicToken' => 's' }],
      'artists' => [{ 'artistName' => 'Tool', 'score' => 95, 'musicToken' => 'a' }])
  end

  it 'separates songs and artists' do
    expect(result.songs.map(&:song_name)).to eq(['One'])
    expect(result.artists.map(&:artist_name)).to eq(['Tool'])
  end

  it 'best_match picks the highest score' do
    expect(result.best_match.score).to eq(95)
  end
end

RSpec.describe Pandoru::Models::PlaylistItem do
  let(:api) { double('APIClient', default_audio_quality: 'highQuality') }

  describe '#audio_url' do
    let(:item) do
      described_class.from_json(api,
        'trackToken' => 'tk',
        'audioUrlMap' => { 'highQuality' => 'http://hi', 'lowQuality' => 'http://lo' })
    end

    it 'returns the url for the requested quality' do
      expect(item.audio_url('lowQuality')).to eq('http://lo')
    end

    it 'falls back to the client default quality' do
      expect(item.audio_url).to eq('http://hi')
    end

    it 'is nil when there is no audio map' do
      expect(described_class.from_json(api, 'trackToken' => 'tk').audio_url).to be_nil
    end
  end

  describe 'feedback + bookmark delegation' do
    let(:item) { described_class.from_json(api, 'trackToken' => 'tk', 'allowFeedback' => true) }

    it 'thumbs_up/down call add_feedback with the rating' do
      expect(api).to receive(:add_feedback).with('tk', true)
      item.thumbs_up
      expect(api).to receive(:add_feedback).with('tk', false)
      item.thumbs_down
    end

    it 'does not submit feedback when not allowed' do
      no_fb = described_class.from_json(api, 'trackToken' => 'tk', 'allowFeedback' => false)
      expect(api).not_to receive(:add_feedback)
      no_fb.thumbs_up
    end

    it 'bookmark_song / bookmark_artist / sleep delegate to the client' do
      expect(api).to receive(:add_song_bookmark).with('tk')
      item.bookmark_song
      expect(api).to receive(:add_artist_bookmark).with('tk')
      item.bookmark_artist
      expect(api).to receive(:sleep_song).with('tk')
      item.sleep
    end
  end
end

RSpec.describe Pandoru::Models::Playlist do
  it 'builds playlist items from the items array' do
    playlist = described_class.from_json(nil,
      'items' => [{ 'trackToken' => 't1', 'songName' => 'One' }])
    expect(playlist.first).to be_a(Pandoru::Models::PlaylistItem)
    expect(playlist.first.song_name).to eq('One')
  end
end

RSpec.describe Pandoru::Models::AdItem do
  it 'is always flagged as an ad' do
    expect(described_class.from_json(nil, 'adToken' => 'ad').is_ad?).to eq(true)
  end
end
