require "rails_helper"

RSpec.describe LoginCode, type: :model do
  it { should belong_to(:user) }
  # code has a before_validation default, so presence validation is tested via set_defaults

  describe ".generate_code" do
    it "generates a 6-digit code" do
      code = LoginCode.generate_code
      expect(code.length).to eq(6)
      expect(code).to match(/\A\d{6}\z/)
    end
  end

  describe "#expired?" do
    it "returns false for valid codes" do
      login_code = build(:login_code, expires_at: 5.minutes.from_now)
      expect(login_code.expired?).to be false
    end

    it "returns true for expired codes" do
      login_code = build(:login_code, expires_at: 1.minute.ago)
      expect(login_code.expired?).to be true
    end
  end
end
