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
end
