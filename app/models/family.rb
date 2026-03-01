class Family < ApplicationRecord
  has_many :family_memberships, dependent: :destroy
  has_many :users, through: :family_memberships
  has_many :people, dependent: :destroy
  has_many :photos, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :uploads, dependent: :destroy

  validates :name, presence: true
end
