# frozen_string_literal: true

require "rails_helper"

RSpec.describe Photo::ConfidenceScorer do
  describe ".score_exif" do
    it "returns the EXIF confidence score" do
      expect(described_class.score_exif(Time.current)).to eq(0.95)
    end
  end

  describe ".score_filename" do
    it "returns the filename confidence score" do
      expect(described_class.score_filename(double("date_result"))).to eq(0.6)
    end
  end

  describe ".score_age_estimate" do
    it "returns 0.85 when person has an exact date_of_birth" do
      person = Person.new(date_of_birth: Date.new(1950, 1, 1), dob_year: 1950)

      expect(described_class.score_age_estimate(person, 25)).to eq(0.85)
    end

    it "returns 0.75 when person has only dob_year" do
      person = Person.new(dob_year: 1950, dob_circa: false)

      expect(described_class.score_age_estimate(person, 25)).to eq(0.75)
    end

    it "returns 0.7 when person has dob_year with circa precision" do
      person = Person.new(dob_year: 1950, dob_circa: true)

      expect(described_class.score_age_estimate(person, 25)).to eq(0.7)
    end
  end

  describe ".score_manual" do
    it "returns the manual confidence score" do
      expect(described_class.score_manual).to eq(0.9)
    end
  end
end
