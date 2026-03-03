require "rails_helper"

RSpec.describe "Locations Search", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user, family: family) }

  before do
    create(:family_membership, user: user, family: family)
    allow(Session).to receive(:find_signed).and_return(session_record)
  end

  describe "GET /locations/search" do
    context "with a matching query" do
      before do
        family.locations.create!(name: "Kenya")
      end

      it "returns local results in JSON" do
        get search_locations_path, params: { q: "Kenya" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["local"]).to be_an(Array)
        expect(body["local"].first["name"]).to eq("Kenya")
        expect(body["google"]).to eq([])
      end
    end

    context "with a short query (< 2 chars)" do
      it "returns empty results" do
        get search_locations_path, params: { q: "K" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["local"]).to eq([])
        expect(body["google"]).to eq([])
      end
    end

    context "with blank query" do
      it "returns empty results" do
        get search_locations_path, params: { q: "" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["local"]).to eq([])
        expect(body["google"]).to eq([])
      end
    end

    context "with family scoping" do
      it "does not return locations from other families" do
        other_family = create(:family)
        other_family.locations.create!(name: "Kenya")

        get search_locations_path, params: { q: "Kenya" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["local"]).to be_empty
      end
    end

    context "with Google API stubbed" do
      before do
        google_service = instance_double(GooglePlacesService)
        allow(GooglePlacesService).to receive(:new).and_return(google_service)
        allow(google_service).to receive(:autocomplete).with("Nairobi", "test-token").and_return(
          [ { place_id: "ChIJ123", description: "Nairobi, Kenya" } ]
        )
      end

      it "includes Google results in response" do
        get search_locations_path,
          params: { q: "Nairobi", session_token: "test-token" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["google"].first["description"]).to eq("Nairobi, Kenya")
      end
    end
  end

  describe "POST /locations/create_from_google" do
    let(:place_details) do
      {
        place_id: "ChIJMombasa",
        name: "Mombasa",
        lat: -4.0435,
        lng: 39.6682,
        formatted_address: "Mombasa, Kenya",
        address_components: [
          { "longText" => "Mombasa", "shortText" => "Mombasa", "types" => [ "locality", "political" ] },
          { "longText" => "Kenya", "shortText" => "KE", "types" => [ "country", "political" ] }
        ]
      }
    end

    before do
      google_service = instance_double(GooglePlacesService)
      allow(GooglePlacesService).to receive(:new).and_return(google_service)
      allow(google_service).to receive(:place_details).with("ChIJMombasa", "test-token").and_return(place_details)
    end

    it "creates location and returns JSON with id and name" do
      expect do
        post create_from_google_locations_path,
          params: { place_id: "ChIJMombasa", session_token: "test-token" }.to_json,
          headers: { "Content-Type" => "application/json" }
      end.to change { family.locations.count }.by(2)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to be_present
      expect(body["name"]).to eq("Mombasa")
    end

    it "creates the parent hierarchy (Kenya)" do
      post create_from_google_locations_path,
        params: { place_id: "ChIJMombasa", session_token: "test-token" }.to_json,
        headers: { "Content-Type" => "application/json" }

      kenya = family.locations.find_by(name: "Kenya")
      mombasa = family.locations.find_by(name: "Mombasa")

      expect(kenya).to be_present
      expect(mombasa).to be_present
      expect(mombasa.parent).to eq(kenya)
    end

    context "when place details are unavailable" do
      before do
        google_service = instance_double(GooglePlacesService)
        allow(GooglePlacesService).to receive(:new).and_return(google_service)
        allow(google_service).to receive(:place_details).with("bad-id", nil).and_return(nil)
      end

      it "returns unprocessable entity" do
        post create_from_google_locations_path,
          params: { place_id: "bad-id" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
