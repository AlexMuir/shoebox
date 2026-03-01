class LoginCode < ApplicationRecord
  EXPIRATION_TIME = 10.minutes
  CODE_LENGTH = 6

  belongs_to :user

  validates :code, presence: true
  validates :expires_at, presence: true

  before_validation :set_defaults, on: :create

  def expired?
    expires_at < Time.current
  end

  def self.generate_code
    SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")
  end

  private

  def set_defaults
    self.code ||= self.class.generate_code
    self.expires_at ||= EXPIRATION_TIME.from_now
  end
end
