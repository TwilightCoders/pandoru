#!/usr/bin/env ruby
require 'bundler/setup'
require 'pandoru'

# Example usage of the Pandoru gem - Ruby port of pydora

# For this example to work, you would need:
# 1. Valid Pandora partner credentials (these are placeholders)
# 2. A valid Pandora user account

begin
  # Create a client using default settings
  # In production, you would configure with real credentials
  client = Pandoru::ClientBuilder.default_client

  # Login (you would need real credentials)
  # client.login("your_email@example.com", "your_password")

  puts "Pandoru (Ruby port of pydora) v#{Pandoru::VERSION}"
  puts "Client created successfully!"
  
  # Example of what you could do with a logged-in client:
  # 
  # # Get user's stations
  # stations = client.get_station_list
  # puts "You have #{stations.size} stations"
  # 
  # # Get a playlist from the first station
  # if stations.any?
  #   playlist = stations.first.get_playlist
  #   puts "First station has #{playlist.size} tracks"
  # 
  #   # Play the first track
  #   track = playlist.first
  #   puts "Now playing: #{track.artist_name} - #{track.song_name}"
  #   puts "Audio URL: #{track.audio_url}"
  # end
  # 
  # # Search for music
  # results = client.search("The Beatles")
  # puts "Found #{results.size} search results"
  # 
  # # Create a station from search results
  # if results.any?
  #   station = client.create_station(search_token: results.first.music_token)
  #   puts "Created station: #{station.name}"
  # end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
