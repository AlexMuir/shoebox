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
end
