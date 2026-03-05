# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stories API", type: :request do
  let(:family) { create(:family) }
  let(:other_family) { create(:family) }
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user, family: family) }
  let(:storytelling_session) { create(:storytelling_session, family: family, created_by: user) }
  let(:photo) { create(:photo, family: family) }

  let(:audio_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new("fake audio data"),
      "audio/webm",
      true,
      original_filename: "recording.webm"
    )
  end

  def authenticate!
    create(:family_membership, user: user, family: family)
    allow(Session).to receive(:find_signed).and_return(session_record)
  end

  describe "POST /storytelling_sessions/:storytelling_session_id/stories" do
    context "when authenticated" do
      before { authenticate! }

      it "creates a story with valid audio file and returns JSON" do
        post storytelling_session_stories_path(storytelling_session),
             params: { story: { photo_id: photo.id, audio: audio_file } }

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body).to include("id", "photo_id", "audio_url")
        expect(body["photo_id"]).to eq(photo.id)
        expect(body["audio_url"]).to be_present
      end

      it "accepts audio/webm content type" do
        webm_file = Rack::Test::UploadedFile.new(
          StringIO.new("webm audio data"),
          "audio/webm",
          true,
          original_filename: "recording.webm"
        )

        post storytelling_session_stories_path(storytelling_session),
             params: { story: { photo_id: photo.id, audio: webm_file } }

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["audio_url"]).to be_present
      end

      it "accepts audio/mp4 content type" do
        mp4_file = Rack::Test::UploadedFile.new(
          StringIO.new("mp4 audio data"),
          "audio/mp4",
          true,
          original_filename: "recording.m4a"
        )

        post storytelling_session_stories_path(storytelling_session),
             params: { story: { photo_id: photo.id, audio: mp4_file } }

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["audio_url"]).to be_present
      end

      it "returns 422 without audio file" do
        post storytelling_session_stories_path(storytelling_session),
             params: { story: { photo_id: photo.id } }

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body).to have_key("errors")
      end

      it "returns 404 for photo_id not in current family" do
        other_photo = create(:photo, family: other_family)

        post storytelling_session_stories_path(storytelling_session),
             params: { story: { photo_id: other_photo.id, audio: audio_file } }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401 / redirects for unauthenticated request" do
        post storytelling_session_stories_path(storytelling_session),
             params: { story: { photo_id: photo.id, audio: audio_file } }

        # Rails passwordless auth redirects to login
        expect(response).to have_http_status(:redirect).or have_http_status(:unauthorized)
      end
    end
  end
end
