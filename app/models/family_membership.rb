class FamilyMembership < ApplicationRecord
  belongs_to :family
  belongs_to :user

  enum :role, { member: "member", admin: "admin" }

  validates :family_id, uniqueness: { scope: :user_id }
end
