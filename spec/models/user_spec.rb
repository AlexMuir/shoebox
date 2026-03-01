require "rails_helper"

RSpec.describe User, type: :model do
  it { should have_many(:family_memberships).dependent(:destroy) }
  it { should have_many(:families).through(:family_memberships) }
  it { should have_many(:sessions).dependent(:destroy) }
  it { should have_many(:login_codes).dependent(:destroy) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:email) }

  describe "#member_of?" do
    let(:user) { create(:user) }
    let(:family) { user.families.first }
    let(:other_family) { create(:family) }

    it "returns true for a family the user belongs to" do
      expect(user.member_of?(family)).to be true
    end

    it "returns false for a family the user does not belong to" do
      expect(user.member_of?(other_family)).to be false
    end
  end
end
