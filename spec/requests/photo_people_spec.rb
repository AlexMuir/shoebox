# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PhotoPeople", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user, family: family) }
  let(:photo) { create(:photo, family: family) }
  let(:person) { create(:person, family: family) }

  before do
    create(:family_membership, user: user, family: family)
    allow(Session).to receive(:find_signed).and_return(session_record)
  end

  describe "POST /photos/:photo_id/photo_people" do
    context "with estimated_age param" do
      it "saves the estimated_age on PhotoPerson" do
        expect {
          post photo_photo_people_path(photo), params: {
            photo_person: {
              person_id: person.id,
              estimated_age: 25
            }
          }
        }.to change(PhotoPerson, :count).by(1)

        photo_person = PhotoPerson.last
        expect(photo_person.estimated_age).to eq(25)
      end

      context "when person has date_of_birth" do
        let(:person_with_dob) { create(:person, family: family, dob_year: 1990) }

        it "triggers DateDeterminationService.from_age_estimate" do
          expect(Photo::DateDeterminationService).to receive(:from_age_estimate).with(
            photo_person: an_instance_of(PhotoPerson)
          )

          post photo_photo_people_path(photo), params: {
            photo_person: {
              person_id: person_with_dob.id,
              estimated_age: 25
            }
          }
        end
      end

      context "when person has no date_of_birth" do
        it "calls DateDeterminationService but it returns nil safely" do
          expect(Photo::DateDeterminationService).to receive(:from_age_estimate).with(
            photo_person: an_instance_of(PhotoPerson)
          ).and_return(nil)

          post photo_photo_people_path(photo), params: {
            photo_person: {
              person_id: person.id,
              estimated_age: 25
            }
          }
        end
      end
    end

    context "without estimated_age param" do
      it "saves PhotoPerson without age (backwards compat)" do
        expect {
          post photo_photo_people_path(photo), params: {
            photo_person: {
              person_id: person.id
            }
          }
        }.to change(PhotoPerson, :count).by(1)

        photo_person = PhotoPerson.last
        expect(photo_person.estimated_age).to be_nil
      end

      it "does not trigger DateDeterminationService" do
        expect(Photo::DateDeterminationService).not_to receive(:from_age_estimate)

        post photo_photo_people_path(photo), params: {
          photo_person: {
            person_id: person.id
          }
        }
      end
    end

    context "with invalid estimated_age" do
      it "rejects age > 120" do
        expect {
          post photo_photo_people_path(photo), params: {
            photo_person: {
              person_id: person.id,
              estimated_age: 150
            }
          }
        }.not_to change(PhotoPerson, :count)
      end

      it "rejects age < 1" do
        expect {
          post photo_photo_people_path(photo), params: {
            photo_person: {
              person_id: person.id,
              estimated_age: 0
            }
          }
        }.not_to change(PhotoPerson, :count)
      end
    end
  end
end
