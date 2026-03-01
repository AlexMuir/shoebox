require "rails_helper"

RSpec.describe Family, type: :model do
  it { should have_many(:family_memberships).dependent(:destroy) }
  it { should have_many(:users).through(:family_memberships) }
  it { should have_many(:people).dependent(:destroy) }
  it { should have_many(:photos).dependent(:destroy) }
  it { should have_many(:events).dependent(:destroy) }
  it { should have_many(:locations).dependent(:destroy) }
  it { should have_many(:uploads).dependent(:destroy) }

  it { should validate_presence_of(:name) }
end
