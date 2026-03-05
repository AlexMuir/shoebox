require "rails_helper"

RSpec.describe StorytellingSession, type: :model do
  describe "associations" do
    it { should belong_to(:family) }
    it { should belong_to(:location).optional }
    it { should belong_to(:created_by).class_name("User") }
    it { should have_many(:storytelling_session_people).dependent(:destroy) }
    it { should have_many(:storytellers).through(:storytelling_session_people).source(:person) }
    it { should have_many(:stories).dependent(:destroy) }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        user = create(:user)
        family = user.families.first

        old_session = create(:storytelling_session, family: family, created_by: user, created_at: 2.days.ago)
        new_session = create(:storytelling_session, family: family, created_by: user, created_at: 1.hour.ago)

        expect(StorytellingSession.recent).to eq([ new_session, old_session ])
      end
    end
  end

  describe "factory" do
    it "creates a valid storytelling session" do
      session = build(:storytelling_session)
      expect(session).to be_valid
    end

    it "creates a valid storytelling session with location" do
      family = create(:family)
      user = create(:user)
      create(:family_membership, family: family, user: user)
      location = create(:location, family: family)

      session = build(:storytelling_session, family: family, created_by: user, location: location)
      expect(session).to be_valid
    end
  end
end
