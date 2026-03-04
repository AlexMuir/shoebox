require "rails_helper"

RSpec.describe Person, type: :model do
  it { should belong_to(:family) }
  it { should have_many(:photo_faces).dependent(:nullify) }
  it { should validate_presence_of(:first_name) }
  it { should validate_presence_of(:last_name) }

  describe "#full_name" do
    it "returns first and last name" do
      person = build(:person, first_name: "Alex", last_name: "Muir")
      expect(person.full_name).to eq("Alex Muir")
    end
  end

  describe "#age" do
    it "returns age from date of birth" do
      travel_to Date.new(2020, 1, 1) do
        person = build(:person, date_of_birth: Date.new(1989, 1, 1))
        expect(person.age).to eq(30)
      end
    end

    it "returns nil without date of birth" do
      person = build(:person, date_of_birth: nil)
      expect(person.age).to be_nil
    end

    it "calculates age at death for deceased people" do
      person = build(:person,
        date_of_birth: Date.new(1930, 1, 1),
        date_of_death: Date.new(2010, 1, 1)
      )
      expect(person.age).to eq(80)
    end
  end

  describe "dob_year field" do
    it "validates numericality with range" do
      person = build(:person, dob_year: 1950)
      expect(person).to be_valid
    end

    it "rejects dob_year below 1000" do
      person = build(:person, dob_year: 999)
      expect(person).not_to be_valid
      expect(person.errors[:dob_year]).to be_present
    end

    it "rejects dob_year above current year" do
      person = build(:person, dob_year: Date.current.year + 1)
      expect(person).not_to be_valid
      expect(person.errors[:dob_year]).to be_present
    end

    it "allows nil dob_year" do
      person = build(:person, dob_year: nil)
      expect(person).to be_valid
    end
  end

  describe "dob_circa field" do
    it "defaults to false" do
      person = build(:person)
      expect(person.dob_circa).to eq(false)
    end
  end

  describe "#dob_text" do
    it "returns circa format when dob_circa is true" do
      person = build(:person, dob_year: 1952, dob_circa: true)
      expect(person.dob_text).to eq("c. 1952")
    end

    it "returns year only when dob_circa is false" do
      person = build(:person, dob_year: 1975, dob_circa: false)
      expect(person.dob_text).to eq("1975")
    end

    it "returns nil when dob_year is nil" do
      person = build(:person, dob_year: nil)
      expect(person.dob_text).to be_nil
    end
  end

  describe "#has_dob?" do
    it "returns true when dob_year is present" do
      person = build(:person, dob_year: 1950)
      expect(person.has_dob?).to eq(true)
    end

    it "returns false when dob_year is nil" do
      person = build(:person, dob_year: nil)
      expect(person.has_dob?).to eq(false)
    end
  end

  describe "DOB change callbacks" do
    it "recalculates all age-based determinations when dob_year changes" do
      person = create(:person, dob_year: 1950)

      photo_one = create(:photo, family: person.family)
      photo_two = create(:photo, family: person.family)

      photo_person = create(:photo_person, photo: photo_one, person: person, estimated_age: 25)
      photo_face = create(:photo_face, photo: photo_two, person: person, estimated_age: 30)

      age_determination_from_person = create(
        :date_determination,
        photo: photo_one,
        photo_person: photo_person,
        source_type: "age_estimate",
        determined_year: 1975,
        confidence: 0.75
      )
      age_determination_from_face = create(
        :date_determination,
        photo: photo_two,
        photo_face: photo_face,
        source_type: "age_estimate",
        determined_year: 1980,
        confidence: 0.75
      )
      non_age_determination = create(
        :date_determination,
        photo: photo_one,
        source_type: "filename",
        determined_year: 1965,
        confidence: 0.6
      )

      allow(Photo::ConfidenceScorer).to receive(:score_age_estimate).with(person, 25).and_return(0.66)
      allow(Photo::ConfidenceScorer).to receive(:score_age_estimate).with(person, 30).and_return(0.67)

      person.update!(dob_year: 1955)

      expect(age_determination_from_person.reload.determined_year).to eq(1980)
      expect(age_determination_from_person.reload.confidence).to eq(0.66)

      expect(age_determination_from_face.reload.determined_year).to eq(1985)
      expect(age_determination_from_face.reload.confidence).to eq(0.67)

      expect(non_age_determination.reload.determined_year).to eq(1965)
      expect(non_age_determination.reload.confidence).to eq(0.6)
    end

    it "recalculates age-based determinations when date_of_birth changes" do
      person = create(:person, dob_year: 1950, date_of_birth: nil)
      photo = create(:photo, family: person.family)
      photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 25)

      determination = create(
        :date_determination,
        photo: photo,
        photo_person: photo_person,
        source_type: "age_estimate",
        determined_year: 1975,
        confidence: 0.75
      )

      person.update!(date_of_birth: Date.new(1950, 6, 10))

      expect(determination.reload.determined_year).to eq(1975)
      expect(determination.reload.determined_month).to eq(6)
      expect(determination.reload.confidence).to eq(0.85)
    end

    it "updates existing age-based determinations in place" do
      person = create(:person, dob_year: 1950)
      photo = create(:photo, family: person.family)
      photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 20)
      determination = create(
        :date_determination,
        photo: photo,
        photo_person: photo_person,
        source_type: "age_estimate",
        determined_year: 1970,
        confidence: 0.75
      )

      expect {
        person.update!(dob_year: 1952)
      }.not_to change(DateDetermination, :count)

      expect(determination.reload.id).to eq(determination.id)
      expect(determination.reload.determined_year).to eq(1972)
      expect(determination.reload.confidence).to eq(0.75)
    end
  end
end
