require "rails_helper"

RSpec.describe StorytellingSessionPerson, type: :model do
  describe "associations" do
    it { should belong_to(:storytelling_session) }
    it { should belong_to(:person) }
  end

  describe "validations" do
    it "validates uniqueness of person scoped to storytelling session" do
      user = create(:user)
      family = user.families.first
      person = create(:person, family: family)
      session = create(:storytelling_session, family: family, created_by: user)

      create(:storytelling_session_person, storytelling_session: session, person: person)
      duplicate = build(:storytelling_session_person, storytelling_session: session, person: person)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:person_id]).to be_present
    end

    it "allows the same person in different sessions" do
      user = create(:user)
      family = user.families.first
      person = create(:person, family: family)

      session1 = create(:storytelling_session, family: family, created_by: user)
      session2 = create(:storytelling_session, family: family, created_by: user)

      create(:storytelling_session_person, storytelling_session: session1, person: person)
      different_session = build(:storytelling_session_person, storytelling_session: session2, person: person)

      expect(different_session).to be_valid
    end
  end

  describe "factory" do
    it "creates a valid storytelling session person" do
      ssp = build(:storytelling_session_person)
      expect(ssp).to be_valid
    end
  end
end
