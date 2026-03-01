class User < ApplicationRecord
  has_many :family_memberships, dependent: :destroy
  has_many :families, through: :family_memberships
  has_many :sessions, dependent: :destroy
  has_many :login_codes, dependent: :destroy
  has_many :contributions, dependent: :destroy
  has_one :person

  enum :role, { member: "member", admin: "admin" }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  normalizes :email, with: -> { _1.strip.downcase }

  scope :kept, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  def can_login?
    email.present?
  end

  def member_of?(family)
    family_memberships.exists?(family: family)
  end

  def send_login_code(**attributes)
    login_codes.create!(attributes).tap do |login_code|
      LoginCodeMailer.sign_in_instructions(login_code).deliver_now
    end
  end
end
