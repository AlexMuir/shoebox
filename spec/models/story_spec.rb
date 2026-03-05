# frozen_string_literal: true

require "rails_helper"

RSpec.describe Story, type: :model do
  describe "associations" do
    it "belongs to a storytelling_session" do
      story = build(:story)
      expect(story.storytelling_session).to be_a(StorytellingSession)
    end

    it "belongs to a photo" do
      story = build(:story)
      expect(story.photo).to be_a(Photo)
    end

    it "requires a storytelling_session" do
      story = build(:story, storytelling_session: nil)
      expect(story).not_to be_valid
      expect(story.errors[:storytelling_session]).to be_present
    end

    it "requires a photo" do
      story = build(:story, photo: nil)
      expect(story).not_to be_valid
      expect(story.errors[:photo]).to be_present
    end
  end

  describe "audio attachment" do
    it "has an audio attachment" do
      story = build(:story)
      expect(story.audio).to be_attached
    end

    it "accepts audio/webm content type" do
      story = build(:story)
      story.audio.attach(
        io: StringIO.new("fake audio"),
        filename: "recording.webm",
        content_type: "audio/webm"
      )
      expect(story).to be_valid
    end

    it "accepts audio/mp4 content type" do
      story = build(:story)
      story.audio.attach(
        io: StringIO.new("fake audio"),
        filename: "recording.mp4",
        content_type: "audio/mp4"
      )
      expect(story).to be_valid
    end

    it "accepts audio/ogg content type" do
      story = build(:story)
      story.audio.attach(
        io: StringIO.new("fake audio"),
        filename: "recording.ogg",
        content_type: "audio/ogg"
      )
      expect(story).to be_valid
    end

    it "accepts audio/mpeg content type" do
      story = build(:story)
      story.audio.attach(
        io: StringIO.new("fake audio"),
        filename: "recording.mp3",
        content_type: "audio/mpeg"
      )
      expect(story).to be_valid
    end

    it "rejects non-audio content types" do
      story = build(:story)
      story.audio.attach(
        io: StringIO.new("fake image"),
        filename: "image.jpg",
        content_type: "image/jpeg"
      )
      expect(story).not_to be_valid
      expect(story.errors[:audio]).to be_present
    end

    it "rejects text content types" do
      story = build(:story)
      story.audio.attach(
        io: StringIO.new("some text"),
        filename: "notes.txt",
        content_type: "text/plain"
      )
      expect(story).not_to be_valid
      expect(story.errors[:audio]).to be_present
    end
  end

  describe "scopes" do
    it ".for_photo returns stories for a specific photo" do
      photo = create(:photo)
      other_photo = create(:photo)

      story_for_photo = create(:story, photo: photo)
      _other_story = create(:story, photo: other_photo)

      expect(Story.for_photo(photo)).to contain_exactly(story_for_photo)
    end
  end

  describe "factory" do
    it "creates a valid story" do
      story = build(:story)
      expect(story).to be_valid
    end

    it "can be persisted" do
      story = create(:story)
      expect(story).to be_persisted
    end
  end
end
