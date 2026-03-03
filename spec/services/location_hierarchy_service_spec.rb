require "rails_helper"

RSpec.describe LocationHierarchyService do
  let(:family) { FactoryBot.create(:family) }

  describe ".call" do
    context "with a country-only place" do
      let(:place_details) do
        {
          place_id: "ChIJKenya",
          name: "Kenya",
          lat: -0.0236,
          lng: 37.9062,
          formatted_address: "Kenya",
          address_components: [
            { "longText" => "Kenya", "shortText" => "KE", "types" => [ "country", "political" ] }
          ]
        }
      end

      it "creates a single root location" do
        result = described_class.call(family, place_details)

        expect(result).to be_a(Location)
        expect(result.name).to eq("Kenya")
        expect(result.google_place_id).to eq("ChIJKenya")
        expect(result.parent).to be_nil
        expect(result.family).to eq(family)
        expect(result.latitude).to be_within(0.001).of(-0.0236)
      end
    end

    context "with a city place (city + country)" do
      let(:place_details) do
        {
          place_id: "ChIJMombasa",
          name: "Mombasa",
          lat: -4.0435,
          lng: 39.6682,
          formatted_address: "Mombasa, Kenya",
          address_components: [
            { "longText" => "Mombasa", "shortText" => "Mombasa", "types" => [ "locality", "political" ] },
            { "longText" => "Kenya", "shortText" => "KE", "types" => [ "country", "political" ] }
          ]
        }
      end

      it "creates Kenya as root and Mombasa as child" do
        result = described_class.call(family, place_details)

        kenya = family.locations.find_by(name: "Kenya")
        expect(kenya).to be_present
        expect(kenya.parent).to be_nil

        expect(result.name).to eq("Mombasa")
        expect(result.parent).to eq(kenya)
        expect(result.google_place_id).to eq("ChIJMombasa")
      end
    end

    context "with an address place (street + city + country)" do
      let(:place_details) do
        {
          place_id: "ChIJFairbourne",
          name: "12 Fairbourne Road",
          lat: 53.4808,
          lng: -2.2426,
          formatted_address: "12 Fairbourne Road, Manchester, UK",
          address_components: [
            { "longText" => "12 Fairbourne Road", "shortText" => "12 Fairbourne Rd", "types" => [ "street_address" ] },
            { "longText" => "Manchester", "shortText" => "Manchester", "types" => [ "locality", "political" ] },
            { "longText" => "United Kingdom", "shortText" => "GB", "types" => [ "country", "political" ] }
          ]
        }
      end

      it "creates UK > Manchester > address hierarchy" do
        result = described_class.call(family, place_details)

        uk = family.locations.find_by(name: "United Kingdom")
        manchester = family.locations.find_by(name: "Manchester")

        expect(uk.parent).to be_nil
        expect(manchester.parent).to eq(uk)
        expect(result.parent).to eq(manchester)
        expect(result.name).to eq("12 Fairbourne Road")
      end
    end

    context "deduplication" do
      it "reuses existing location by google_place_id for leaf" do
        existing = family.locations.create!(name: "Mombasa", google_place_id: "ChIJMombasa")

        place_details = {
          place_id: "ChIJMombasa",
          name: "Mombasa",
          lat: -4.0435,
          lng: 39.6682,
          formatted_address: "Mombasa, Kenya",
          address_components: [
            { "longText" => "Mombasa", "shortText" => "Mombasa", "types" => [ "locality", "political" ] },
            { "longText" => "Kenya", "shortText" => "KE", "types" => [ "country", "political" ] }
          ]
        }

        result = described_class.call(family, place_details)

        expect(result.id).to eq(existing.id)
        expect(family.locations.where(google_place_id: "ChIJMombasa").count).to eq(1)
      end

      it "reuses existing parent by name when it exists" do
        existing_kenya = family.locations.create!(name: "Kenya")

        place_details = {
          place_id: "ChIJMombasa2",
          name: "Mombasa",
          lat: -4.0435,
          lng: 39.6682,
          formatted_address: "Mombasa, Kenya",
          address_components: [
            { "longText" => "Mombasa", "shortText" => "Mombasa", "types" => [ "locality", "political" ] },
            { "longText" => "Kenya", "shortText" => "KE", "types" => [ "country", "political" ] }
          ]
        }

        result = described_class.call(family, place_details)

        expect(result.parent.id).to eq(existing_kenya.id)
        expect(family.locations.where(name: "Kenya").count).to eq(1)
      end
    end

    context "family scoping" do
      it "does not use locations from other families" do
        other_family = FactoryBot.create(:family)
        other_kenya = other_family.locations.create!(name: "Kenya")

        place_details = {
          place_id: "ChIJKenya2",
          name: "Kenya",
          lat: -0.0236,
          lng: 37.9062,
          formatted_address: "Kenya",
          address_components: [
            { "longText" => "Kenya", "shortText" => "KE", "types" => [ "country", "political" ] }
          ]
        }

        result = described_class.call(family, place_details)

        expect(result.family).to eq(family)
        expect(result.id).not_to eq(other_kenya.id)
      end
    end
  end
end
