# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Photos JSON API", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user, family: family) }

  before do
    create(:family_membership, user: user, family: family)
    allow(Session).to receive(:find_signed).and_return(session_record)
  end

  describe "GET /photos/:id.json" do
    let(:photo) { create(:photo, family: family) }

    it "returns 200 with correct JSON shape" do
      get photo_path(photo), headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include("id", "title", "image_url", "faces", "people", "contributions", "prev_id", "next_id")
    end

    it "returns faces as an array" do
      get photo_path(photo), headers: { "Accept" => "application/json" }
      body = JSON.parse(response.body)
      expect(body["faces"]).to be_an(Array)
    end

    it "returns prev_id as nil for the most recent photo" do
      get photo_path(photo), headers: { "Accept" => "application/json" }
      body = JSON.parse(response.body)
      expect(body["prev_id"]).to be_nil
    end

    it "returns next_id as nil for the oldest photo" do
      get photo_path(photo), headers: { "Accept" => "application/json" }
      body = JSON.parse(response.body)
      expect(body["next_id"]).to be_nil
    end

    it "returns prev_id and next_id for a middle photo" do
      older = create(:photo, family: family, created_at: 2.days.ago)
      middle = create(:photo, family: family, created_at: 1.day.ago)
      newer = create(:photo, family: family, created_at: Time.current)

      # ordered_ids is desc by created_at: [newer, middle, older]
      # prev_id = ordered_ids[index+1] = older photo
      # next_id = ordered_ids[index-1] = newer photo
      get photo_path(middle), headers: { "Accept" => "application/json" }
      body = JSON.parse(response.body)
      expect(body["prev_id"]).to eq(older.id)
      expect(body["next_id"]).to eq(newer.id)
    end

    it "includes tagged face data with person info" do
      person = create(:person, family: family)
      create(:photo_face, photo: photo, x: 0.1, y: 0.1, width: 0.2, height: 0.2, person: person)

      get photo_path(photo), headers: { "Accept" => "application/json" }
      body = JSON.parse(response.body)
      expect(body["faces"].length).to eq(1)
      expect(body["faces"].first["person"]).to include("id" => person.id)
    end

    it "includes stories array with session and storyteller data" do
      session = create(:storytelling_session, family: family)
      storyteller = create(:person, family: family)
      create(:storytelling_session_person, storytelling_session: session, person: storyteller)
      story = create(:story, photo: photo, storytelling_session: session)

      get photo_path(photo), headers: { "Accept" => "application/json" }
      body = JSON.parse(response.body)
      expect(body).to include("stories")
      expect(body["stories"]).to be_an(Array)
      expect(body["stories"].length).to eq(1)

      story_data = body["stories"].first
      expect(story_data).to include("id", "audio_url", "storytelling_session")
      expect(story_data["storytelling_session"]).to include("id", "storytellers", "location")
      expect(story_data["storytelling_session"]["storytellers"]).to be_an(Array)
      expect(story_data["storytelling_session"]["storytellers"].first).to include("id", "name")
    end

    it "returns empty stories array when photo has no stories" do
      get photo_path(photo), headers: { "Accept" => "application/json" }
      body = JSON.parse(response.body)
      expect(body["stories"]).to eq([])
    end
  end
end
