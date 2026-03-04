require "rails_helper"

RSpec.describe PhotoFace, type: :model do
  it { should belong_to(:photo) }
  it { should belong_to(:person).optional }
  it { should validate_presence_of(:x) }
  it { should validate_presence_of(:y) }
  it { should validate_presence_of(:width) }
  it { should validate_presence_of(:height) }

  describe "bounds validation" do
    it "rejects a face that extends beyond image width" do
      photo_face = build(:photo_face, x: 0.9, width: 0.2)

      expect(photo_face).not_to be_valid
      expect(photo_face.errors[:width]).to include("extends outside image bounds")
    end

    it "rejects a face that extends beyond image height" do
      photo_face = build(:photo_face, y: 0.85, height: 0.3)

      expect(photo_face).not_to be_valid
      expect(photo_face.errors[:height]).to include("extends outside image bounds")
    end
  end

  describe "estimated_age validation" do
    it "allows nil estimated_age" do
      photo_face = build(:photo_face, estimated_age: nil)

      expect(photo_face).to be_valid
    end

    it "allows valid age between 1 and 120" do
      photo_face = build(:photo_face, estimated_age: 45)

      expect(photo_face).to be_valid
    end

    it "allows age of 1" do
      photo_face = build(:photo_face, estimated_age: 1)

      expect(photo_face).to be_valid
    end

    it "allows age of 120" do
      photo_face = build(:photo_face, estimated_age: 120)

      expect(photo_face).to be_valid
    end

    it "rejects age of 0" do
      photo_face = build(:photo_face, estimated_age: 0)

      expect(photo_face).not_to be_valid
      expect(photo_face.errors[:estimated_age]).to be_present
    end

    it "rejects age greater than 120" do
      photo_face = build(:photo_face, estimated_age: 150)

      expect(photo_face).not_to be_valid
      expect(photo_face.errors[:estimated_age]).to be_present
    end
  end

  describe "preview helpers" do
    it "calculates center and zoom from coordinates" do
      photo_face = build(:photo_face, x: 0.1, y: 0.2, width: 0.25, height: 0.3)

      expect(photo_face.center_x).to eq(0.225)
      expect(photo_face.center_y).to eq(0.35)
      expect(photo_face.preview_zoom).to eq(3.33)
    end
  end
end
