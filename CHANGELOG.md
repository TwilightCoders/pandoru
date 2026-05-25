# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `Station#add_seed` passed its arguments to `add_music` in the wrong order
  (station and music tokens swapped), producing a malformed `station.addMusic`
  request. It now calls `add_music(music_token, token)`.

## [0.1.0] - 2026-05-25

Initial public release. A Ruby port of pydora (tracking upstream `pydora 2.3.1`)
targeting Pandora's partner/device JSON API (`tuner.pandora.com/services/json/`).

### Added
- `Station` model now parses extended attributes: music seeds
  (`seed_artists`, `seed_songs`, `seed_genres`) and feedback
  (`thumbs_up`, `thumbs_down`) via new `StationSeed`/`StationSeeds`,
  `SongFeedback`/`StationFeedback` sub-models.
- `TrackExplanation` model for `track.explainTrack`, exposing `focus_traits`
  (the Music-Genome-derived trait tags) with the trailing filler entry
  stripped. `APIClient#explain_track` now returns this model.
- `base64` declared as an explicit runtime dependency (removed from Ruby's
  default gems in 3.4).

### Fixed
- Partner authentication: the default partner **username** is now `android`
  (the canonical partner) rather than `android-generic` (which is the
  *device model*). The previous value caused `partnerLogin` to fail with
  INVALID_PARTNER_LOGIN.
- Corrected the encryption/decryption key orientation in the bundled default
  partner settings.

[0.1.0]: https://github.com/TwilightCoders/pandoru/releases/tag/v0.1.0
