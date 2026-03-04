# frozen_string_literal: true

require "rails_helper"

RSpec.describe "People", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user, family: family) }
  let(:person) { create(:person, family: family) }

  before do
    create(:family_membership, user: user, family: family)
    allow(Session).to receive(:find_signed).and_return(session_record)
  end

  describe "POST /people" do
    context "with dob_year and dob_circa params" do
      it "saves dob_year and dob_circa on person" do
        expect {
          post people_path, params: {
            person: {
              first_name: "John",
              last_name: "Doe",
              dob_year: 1952,
              dob_circa: "1"
            }
          }
        }.to change(Person, :count).by(1)

        new_person = Person.last
        expect(new_person.dob_year).to eq(1952)
        expect(new_person.dob_circa).to eq(true)
      end
    end

    context "with dob_year only" do
      it "saves dob_year without circa" do
        expect {
          post people_path, params: {
            person: {
              first_name: "Jane",
              last_name: "Smith",
              dob_year: 1960
            }
          }
        }.to change(Person, :count).by(1)

        new_person = Person.last
        expect(new_person.dob_year).to eq(1960)
        expect(new_person.dob_circa).to eq(false)
      end
    end

    context "without dob fields" do
      it "creates person without dob" do
        expect {
          post people_path, params: {
            person: {
              first_name: "Bob",
              last_name: "Johnson"
            }
          }
        }.to change(Person, :count).by(1)

        new_person = Person.last
        expect(new_person.dob_year).to be_nil
        expect(new_person.dob_circa).to eq(false)
      end
    end
  end

  describe "PATCH /people/:id" do
    context "with dob_year and dob_circa params" do
      it "updates dob_year and dob_circa on person" do
        patch person_path(person), params: {
          person: {
            first_name: person.first_name,
            last_name: person.last_name,
            dob_year: 1952,
            dob_circa: "1"
          }
        }

        person.reload
        expect(person.dob_year).to eq(1952)
        expect(person.dob_circa).to eq(true)
      end
    end

    context "updating dob_year only" do
      it "updates dob_year without affecting circa" do
        person.update(dob_year: 1950, dob_circa: true)

        patch person_path(person), params: {
          person: {
            first_name: person.first_name,
            last_name: person.last_name,
            dob_year: 1955
          }
        }

        person.reload
        expect(person.dob_year).to eq(1955)
        expect(person.dob_circa).to eq(true)
      end
    end
  end

  describe "GET /people/:id/edit" do
    it "renders form with dob_year and dob_circa fields" do
      person.update(dob_year: 1952, dob_circa: true)

      get edit_person_path(person)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="person[dob_year]"')
      expect(response.body).to include('name="person[dob_circa]"')
    end
  end

  describe "GET /people/:id" do
    context "when person has dob_year and dob_circa" do
      it "displays dob_text on show page" do
        person.update(dob_year: 1952, dob_circa: true)

        get person_path(person)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("c. 1952")
      end
    end

    context "when person has dob_year without circa" do
      it "displays year without circa prefix" do
        person.update(dob_year: 1960, dob_circa: false)

        get person_path(person)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("1960")
      end
    end

    context "when person has no dob_year" do
      it "does not display dob_text" do
        person.update(dob_year: nil, dob_circa: false)

        get person_path(person)

        expect(response).to have_http_status(:success)
        # Should not have dob_text displayed
        expect(response.body).not_to include("c. ")
      end
    end
  end
end
