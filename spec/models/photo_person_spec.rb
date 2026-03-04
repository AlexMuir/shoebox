require "rails_helper"

RSpec.describe PhotoPerson, type: :model do
  it { should belong_to(:photo) }
  it { should belong_to(:person) }

  describe "estimated_age validation" do
    it "allows nil estimated_age" do
      photo_person = build(:photo_person, estimated_age: nil)

      expect(photo_person).to be_valid
    end

    it "allows valid age between 1 and 120" do
      photo_person = build(:photo_person, estimated_age: 25)

      expect(photo_person).to be_valid
    end

    it "allows age of 1" do
      photo_person = build(:photo_person, estimated_age: 1)

      expect(photo_person).to be_valid
    end

    it "allows age of 120" do
      photo_person = build(:photo_person, estimated_age: 120)

      expect(photo_person).to be_valid
    end

    it "rejects age of 0" do
      photo_person = build(:photo_person, estimated_age: 0)

      expect(photo_person).not_to be_valid
      expect(photo_person.errors[:estimated_age]).to be_present
    end

    it "rejects age greater than 120" do
      photo_person = build(:photo_person, estimated_age: 150)

      expect(photo_person).not_to be_valid
      expect(photo_person.errors[:estimated_age]).to be_present
    end
  end
end
