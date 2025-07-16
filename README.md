# Pandoru

**Pandoru** is a Ruby port of the Python `pydora` library, providing a comprehensive client for the unofficial Pandora music streaming API. This gem allows you to interact with Pandora programmatically to manage stations, get playlists, search for music, and control playback.

> **Note**: This is an unofficial API client. Use at your own risk and respect Pandora's terms of service.

---

## Features

- **Station Management**: Get station lists, create/delete stations, rename stations
- **Playlist Access**: Retrieve playlists with track metadata and audio URLs  
- **Music Search**: Search for songs, artists, and albums
- **User Interaction**: Thumbs up/down, bookmarks, sleep songs
- **Feedback Management**: Add/remove track feedback
- **Genre Exploration**: Browse and create stations from genre seeds
- **Multiple Audio Qualities**: Support for low, medium, and high quality audio streams
- **Ruby Idioms**: Built with Ruby best practices and idiomatic patterns

---

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pandoru'
```

Then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install pandoru
```

---

## Usage

### Configuration

Pandoru requires Pandora partner credentials to function. You can configure these in several ways:

#### 1. Using a Configuration Hash

```ruby
require 'pandoru'

# Note: These are example credentials - you need real ones
settings = {
  "PARTNER_USER" => "your-partner-user",
  "PARTNER_PASSWORD" => "your-partner-password", 
  "DEVICE" => "your-device-type",
  "DECRYPTION_KEY" => "your-decryption-key",
  "ENCRYPTION_KEY" => "your-encryption-key"
}

client = Pandoru::ClientBuilder.from_settings_hash(settings)
client.login("your_email@example.com", "your_password")
```

#### 2. Using Configuration Files

Pandoru supports both pydora-style and pianobar-style configuration files:

```ruby
# From a pydora config file
client = Pandoru::ClientBuilder.from_config_file("~/.pydora.cfg")

# From a pianobar config file  
client = Pandoru::ClientBuilder.from_config_file("~/.config/pianobar/config")
```

### Basic Operations

#### Managing Stations

```ruby
# Get all user stations
stations = client.get_station_list

# Create a new station from search results
search_results = client.search("Radiohead")
station = client.create_station(search_token: search_results.first.music_token)

# Rename a station
client.rename_station(station.token, "My Radiohead Station")

# Delete a station
client.delete_station(station.token)
```

#### Working with Playlists

```ruby
# Get a playlist from a station
playlist = client.get_playlist(station.token)

playlist.each do |track|
  puts "#{track.artist_name} - #{track.song_name}"
  puts "Audio URL: #{track.audio_url}"
  
  # Rate the track
  track.thumbs_up if track.allow_feedback
  
  # Bookmark the song or artist
  track.bookmark_song
  track.bookmark_artist
end
```

#### Searching for Music

```ruby
# Search for music
results = client.search("The Beatles", include_near_matches: true)

results.songs.each do |song|
  puts "Song: #{song.song_name} by #{song.artist_name}"
end

results.artists.each do |artist|
  puts "Artist: #{artist.artist_name}"
end
```

#### Managing Bookmarks

```ruby
# Get user bookmarks
bookmarks = client.get_bookmarks

bookmarks.song_bookmarks.each do |bookmark|
  puts "Bookmarked song: #{bookmark.song_name} by #{bookmark.artist_name}"
end

bookmarks.artist_bookmarks.each do |bookmark|
  puts "Bookmarked artist: #{bookmark.artist_name}"
end
```

### Advanced Features

#### Genre Stations

```ruby
# Browse genre stations
genre_stations = client.get_genre_stations

genre_stations.categories.each do |category|
  puts "Category: #{category}"
  genre_stations.stations_for_category(category).each do |station|
    puts "  Station: #{station.name}"
  end
end
```

#### Audio Quality

```ruby
# Set default audio quality when creating client
client = Pandoru::ClientBuilder.from_settings_hash(settings.merge(
  "AUDIO_QUALITY" => "highQuality"  # or "mediumQuality", "lowQuality"
))

# Get specific quality audio URL for a track
track = playlist.first
high_quality_url = track.audio_url("highQuality")
medium_quality_url = track.audio_url("mediumQuality")  
low_quality_url = track.audio_url("lowQuality")
```

#### Error Handling

```ruby
begin
  client.login("user@example.com", "password")
rescue Pandoru::Errors::InvalidUserLogin
  puts "Invalid username or password"
rescue Pandoru::Errors::PandoraException => e
  puts "Pandora API error: #{e.message} (Code: #{e.code})"
end
```

---

## API Reference

### Client Classes

- `Pandoru::Client::APIClient` - High-level API client with all Pandora operations
- `Pandoru::Client::BaseAPIClient` - Lower-level client for advanced usage

### Models

- `Pandoru::Models::Station` - Represents a Pandora station
- `Pandoru::Models::StationList` - Collection of user stations  
- `Pandoru::Models::Playlist` - Collection of playlist items
- `Pandoru::Models::PlaylistItem` - Individual track in a playlist
- `Pandoru::Models::SearchResult` - Search results container
- `Pandoru::Models::BookmarkList` - User's bookmarked songs and artists

### Client Builders

- `Pandoru::ClientBuilder.from_settings_hash(hash)` - Create client from settings hash
- `Pandoru::ClientBuilder.from_config_file(path)` - Create client from config file
- `Pandoru::ClientBuilder.default_client()` - Create client with default settings

---

## Architecture

Pandoru is architected similarly to the original pydora library:

- **Transport Layer**: Handles HTTP communication and encryption/decryption
- **Client Layer**: Provides high-level API methods
- **Models Layer**: Represents Pandora data structures with Ruby idioms
- **Builders Layer**: Factory classes for creating configured clients

The Ruby port maintains compatibility with pydora's API while providing Ruby-style interfaces and error handling.

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

---

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/TwilightCoders/pandoru.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

---

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

## Acknowledgments

This Ruby gem is a port of the excellent [pydora](https://github.com/mcrute/pydora) Python library by Mike Crute and contributors. All credit for the original API reverse engineering and design goes to the pydora project.

## Disclaimer

This project is not affiliated with or endorsed by Pandora Media, Inc. Use of this library may violate Pandora's Terms of Service. Use at your own risk.
