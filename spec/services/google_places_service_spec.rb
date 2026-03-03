require "rails_helper"

RSpec.describe GooglePlacesService do
  let(:service) { described_class.new }
  let(:api_key) { "test-api-key" }
  let(:session_token) { "session-123" }

  describe "#autocomplete" do
    let(:url) { "https://places.googleapis.com/v1/places:autocomplete" }

    before do
      allow(Rails.application.credentials).to receive(:dig).with(:google, :places_api_key).and_return(api_key)
    end

    it "returns mapped suggestions on success" do
      stub_request(:post, url)
        .with(
          body: hash_including("input" => "Mombasa", "sessionToken" => session_token),
          headers: {
            "Content-Type" => "application/json",
            "X-Goog-Api-Key" => api_key
          }
        )
        .to_return(
          status: 200,
          body: {
            suggestions: [
              {
                placePrediction: {
                  placeId: "abc123",
                  text: { text: "Mombasa, Kenya" }
                }
              }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.autocomplete("Mombasa", session_token)

      expect(result).to eq([ { place_id: "abc123", description: "Mombasa, Kenya" } ])
    end

    it "returns empty array when API key is missing" do
      allow(Rails.application.credentials).to receive(:dig).with(:google, :places_api_key).and_return(nil)

      result = service.autocomplete("Mombasa", session_token)

      expect(result).to eq([])
      expect(WebMock).not_to have_requested(:post, url)
    end

    it "returns empty array on timeout" do
      stub_request(:post, url).to_timeout

      result = service.autocomplete("Mombasa", session_token)

      expect(result).to eq([])
    end

    it "returns empty array on server error" do
      stub_request(:post, url)
        .to_return(status: 500, body: { error: "server error" }.to_json, headers: { "Content-Type" => "application/json" })

      result = service.autocomplete("Mombasa", session_token)

      expect(result).to eq([])
    end
  end

  describe "#place_details" do
    let(:place_id) { "abc123" }
    let(:base_url) { "https://places.googleapis.com/v1/places/#{place_id}" }

    before do
      allow(Rails.application.credentials).to receive(:dig).with(:google, :places_api_key).and_return(api_key)
    end

    it "returns mapped place details on success" do
      stub_request(:get, /places.googleapis.com\/v1\/places\/abc123/)
        .with(
          headers: {
            "X-Goog-Api-Key" => api_key,
            "X-Goog-FieldMask" => "id,displayName,formattedAddress,location,addressComponents"
          }
        )
        .to_return(
          status: 200,
          body: {
            id: place_id,
            displayName: { text: "Mombasa", languageCode: "en" },
            formattedAddress: "Mombasa, Kenya",
            location: { latitude: -4.0435, longitude: 39.6682 },
            addressComponents: [
              { longText: "Kenya", shortText: "KE", types: [ "country", "political" ] }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = service.place_details(place_id, session_token)

      expect(result).to eq(
        {
          place_id: place_id,
          name: "Mombasa",
          lat: -4.0435,
          lng: 39.6682,
          address_components: [
            { "longText" => "Kenya", "shortText" => "KE", "types" => [ "country", "political" ] }
          ],
          formatted_address: "Mombasa, Kenya"
        }
      )
      expect(WebMock).to have_requested(:get, "#{base_url}?sessionToken=#{session_token}")
    end

    it "returns nil when API key is missing" do
      allow(Rails.application.credentials).to receive(:dig).with(:google, :places_api_key).and_return(nil)

      result = service.place_details(place_id, session_token)

      expect(result).to be_nil
      expect(WebMock).not_to have_requested(:get, /places.googleapis.com\/v1\/places\/abc123/)
    end

    it "returns nil on network error" do
      stub_request(:get, /places.googleapis.com\/v1\/places\/abc123/).to_raise(Net::ReadTimeout)

      result = service.place_details(place_id, session_token)

      expect(result).to be_nil
    end
  end
end
