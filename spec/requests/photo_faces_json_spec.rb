# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PhotoFaces JSON API", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user, family: family) }
  let(:photo) { create(:photo, family: family) }

  before do
    create(:family_membership, user: user, family: family)
    allow(Session).to receive(:find_signed).and_return(session_record)
  end

  describe "POST /photos/:photo_id/photo_faces.json" do
    let(:valid_params) { { photo_face: { x: 0.3, y: 0.3, width: 0.1, height: 0.1 } } }

    it "creates a face and returns 201 with JSON" do
      post photo_photo_faces_path(photo),
           params: valid_params,
           headers: { "Accept" => "application/json" },
           as: :json
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include("id", "x", "y", "width", "height")
    end

    it "creates a face with estimated_age and returns it in JSON" do
      post photo_photo_faces_path(photo),
           params: { photo_face: { x: 0.3, y: 0.3, width: 0.1, height: 0.1, estimated_age: 30 } },
           headers: { "Accept" => "application/json" },
           as: :json
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include("id", "x", "y", "width", "height", "estimated_age")
      expect(body["estimated_age"]).to eq(30)
    end

    it "returns 422 with errors for invalid params" do
      post photo_photo_faces_path(photo),
           params: { photo_face: { x: 1.5, y: 0.3, width: 0.1, height: 0.1 } },
           headers: { "Accept" => "application/json" },
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body).to have_key("errors")
    end
  end

  describe "PATCH /photos/:photo_id/photo_faces/:id.json" do
    let(:face) { create(:photo_face, photo: photo, x: 0.3, y: 0.3, width: 0.1, height: 0.1) }
    let(:person) { create(:person, family: family) }

    it "updates the face and returns 200 with JSON" do
      patch photo_photo_face_path(photo, face),
            params: { photo_face: { person_id: person.id } },
            headers: { "Accept" => "application/json" },
            as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["person"]).to include("id" => person.id)
    end

    it "updates face with estimated_age and saves it" do
      patch photo_photo_face_path(photo, face),
            params: { photo_face: { estimated_age: 25 } },
            headers: { "Accept" => "application/json" },
            as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["estimated_age"]).to eq(25)
      face.reload
      expect(face.estimated_age).to eq(25)
    end

    it "triggers DateDeterminationService when assigning person with estimated_age" do
      person.update!(date_of_birth: "1990-01-15")
      expect(Photo::DateDeterminationService).to receive(:from_age_estimate).with(photo_face: instance_of(PhotoFace))
      patch photo_photo_face_path(photo, face),
            params: { photo_face: { person_id: person.id, estimated_age: 30 } },
            headers: { "Accept" => "application/json" },
            as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /photos/:photo_id/photo_faces/:id.json" do
    let(:face) { create(:photo_face, photo: photo, x: 0.3, y: 0.3, width: 0.1, height: 0.1) }

    it "destroys the face and returns success JSON" do
      delete photo_photo_face_path(photo, face),
             headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to be true
    end
  end
end
