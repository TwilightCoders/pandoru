require_relative '_base'

module Pandoru
  module Models
    # A single Music-Genome-derived trait from track.explainTrack, e.g.
    # "electric rock instrumentation" or "a subtle use of vocal harmony".
    class FocusTrait < Base
      field :focus_trait_id, 'focusTraitId'
      field :focus_trait_name, 'focusTraitName'

      def to_s
        focus_trait_name.to_s
      end
    end

    # The result of track.explainTrack: the human-readable traits the Music
    # Genome Project used to justify playing a track. This is the closest the
    # API gets to exposing genome data — discrete trait tags, not a vector.
    class TrackExplanation < Base
      attr_accessor :explanations

      def self.from_json(api_client, data)
        return nil unless data
        instance = new(data, api_client)
        instance.explanations =
          FocusTrait.from_json_list(api_client, data['explanations'])
        instance
      end

      # The genome-derived trait name strings, with the trailing filler entry
      # removed. The API always appends a non-attribute entry as the last
      # explanation ("...many other similarities identified in the Music
      # Genome Project"); it carries no focusTraitId, so we drop it.
      def focus_traits
        traits = explanations || []
        traits = traits[0...-1] if traits.last && traits.last.focus_trait_id.nil?
        traits.map(&:focus_trait_name).compact
      end
    end
  end
end
