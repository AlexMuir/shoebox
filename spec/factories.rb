# frozen_string_literal: true

FactoryBot.define do
  factory :family do
    sequence(:name) { |n| "Family #{n}" }
  end

  factory :user do
    name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@example.com" }
    role { :member }

    trait :admin do
      role { :admin }
    end

    after(:create) do |user, evaluator|
      create(:family_membership, user: user) unless user.families.any?
    end
  end

  factory :family_membership do
    family
    user
    role { :member }

    trait :admin do
      role { :admin }
    end
  end

  factory :session do
    user
    family { user.families.first || create(:family) }
    ip_address { "127.0.0.1" }
    user_agent { "RSpec Test Agent" }
  end

  factory :login_code do
    user
    code { LoginCode.generate_code }
    expires_at { 10.minutes.from_now }

    trait :expired do
      expires_at { 1.minute.ago }
    end
  end

  factory :person do
    family
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    trait :with_dates do
      date_of_birth { Faker::Date.birthday(min_age: 20, max_age: 80) }
    end

    trait :with_dob do
      dob_year { rand(1900..Date.current.year - 18) }
      dob_circa { false }
    end

    trait :deceased do
      date_of_birth { Faker::Date.birthday(min_age: 60, max_age: 90) }
      date_of_death { Faker::Date.between(from: 2.years.ago, to: Date.current) }
    end
  end

  factory :location do
    family
    name { Faker::Address.city }

    trait :with_address do
      address_line_1 { Faker::Address.street_address }
      city { Faker::Address.city }
      region { Faker::Address.state }
      postal_code { Faker::Address.zip_code }
      country { Faker::Address.country }
    end
  end

  factory :event do
    family
    title { "#{Faker::Verb.past_participle.capitalize} #{Faker::Lorem.word}" }

    trait :with_dates do
      date_type { "year" }
      year_from { rand(1960..2020) }
    end
  end

  factory :photo do
    family
    title { "Photo #{SecureRandom.hex(3)}" }

    after(:build) do |photo|
      unless photo.original.attached?
        photo.original.attach(
          io: StringIO.new("fake image data"),
          filename: "test_photo.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :with_date do
      date_type { "year" }
      year { rand(1960..2020) }
    end
  end

  factory :upload do
    family
    user
    source_album { "Photo Album" }
    status { "completed" }
  end

  factory :photo_source do
    photo
    description { "Family Album" }
  end

  factory :contribution do
    photo
    user
    field_name { "date" }
    value { "Summer 1985" }
  end

  factory :photo_person do
    photo
    person
  end

  factory :photo_face do
    photo
    x { 0.1 }
    y { 0.1 }
    width { 0.2 }
    height { 0.2 }

    trait :tagged do
      person { association(:person, family: photo.family) }
    end
  end
end
