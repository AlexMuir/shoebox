require "rails_helper"

RSpec.describe Photo::DateExtractor do
  subject(:result) { described_class.call(filename) }

  # ── Full datetime patterns ──────────────────────────────────────────

  describe "underscored ISO (user's format)" do
    let(:filename) { "2010_02_13_09_57_10.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.hour).to eq(9)
      expect(result.minute).to eq(57)
      expect(result.second).to eq(10)
      expect(result.pattern).to eq(:underscored_iso)
    end
  end

  describe "dashed ISO datetime" do
    let(:filename) { "2010-02-13_09-57-10.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.hour).to eq(9)
      expect(result.minute).to eq(57)
      expect(result.second).to eq(10)
      expect(result.pattern).to eq(:dashed_iso)
    end
  end

  describe "dashed ISO with all dashes" do
    let(:filename) { "photo-2010-02-13-09-57-10.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2010)
      expect(result.day).to eq(13)
      expect(result.pattern).to eq(:dashed_iso)
    end
  end

  describe "macOS screenshot" do
    let(:filename) { "Screenshot 2023-01-15 at 14.20.33.png" }

    it "extracts full datetime" do
      expect(result.year).to eq(2023)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
      expect(result.hour).to eq(14)
      expect(result.minute).to eq(20)
      expect(result.second).to eq(33)
      expect(result.pattern).to eq(:macos_screenshot)
    end
  end

  describe "Android standard (IMG_YYYYMMDD_HHMMSS)" do
    let(:filename) { "IMG_20200615_143052.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2020)
      expect(result.month).to eq(6)
      expect(result.day).to eq(15)
      expect(result.hour).to eq(14)
      expect(result.minute).to eq(30)
      expect(result.second).to eq(52)
      expect(result.pattern).to eq(:compact_datetime)
    end
  end

  describe "Google Pixel" do
    let(:filename) { "PXL_20210415_180322045.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2021)
      expect(result.month).to eq(4)
      expect(result.day).to eq(15)
      expect(result.hour).to eq(18)
      expect(result.minute).to eq(3)
      expect(result.second).to eq(22)
      expect(result.pattern).to eq(:compact_datetime)
    end
  end

  describe "Android screenshot" do
    let(:filename) { "Screenshot_20230115-142033.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2023)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
      expect(result.hour).to eq(14)
      expect(result.minute).to eq(20)
      expect(result.second).to eq(33)
      expect(result.pattern).to eq(:compact_datetime)
    end
  end

  describe "Nikon/Sony DSC format" do
    let(:filename) { "DSC_20100213_095710.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.hour).to eq(9)
      expect(result.minute).to eq(57)
      expect(result.second).to eq(10)
    end
  end

  describe "compact YYYYMMDD_HHMMSS (no prefix)" do
    let(:filename) { "20100213_095710.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.hour).to eq(9)
      expect(result.minute).to eq(57)
      expect(result.second).to eq(10)
      expect(result.pattern).to eq(:compact_datetime)
    end
  end

  describe "Telegram" do
    let(:filename) { "photo_2023-06-15_14-20-33.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2023)
      expect(result.month).to eq(6)
      expect(result.day).to eq(15)
      expect(result.hour).to eq(14)
      expect(result.minute).to eq(20)
      expect(result.second).to eq(33)
      expect(result.pattern).to eq(:telegram)
    end
  end

  describe "Signal" do
    let(:filename) { "signal-2023-06-15-142033.jpg" }

    it "extracts full datetime" do
      expect(result.year).to eq(2023)
      expect(result.month).to eq(6)
      expect(result.day).to eq(15)
      expect(result.hour).to eq(14)
      expect(result.minute).to eq(20)
      expect(result.second).to eq(33)
      expect(result.pattern).to eq(:signal)
    end
  end

  # ── Date-only patterns ──────────────────────────────────────────────

  describe "WhatsApp" do
    let(:filename) { "IMG-20200615-WA0023.jpg" }

    it "extracts date without time" do
      expect(result.year).to eq(2020)
      expect(result.month).to eq(6)
      expect(result.day).to eq(15)
      expect(result.hour).to be_nil
      expect(result.pattern).to eq(:whatsapp)
      expect(result).to be_date_only
    end
  end

  describe "dashed date only" do
    let(:filename) { "photo-2010-02-13.jpg" }

    it "extracts date" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.hour).to be_nil
      expect(result.pattern).to eq(:dashed_date)
    end
  end

  describe "underscored date only" do
    let(:filename) { "2010_02_13.jpg" }

    it "extracts date" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.pattern).to eq(:underscored_date)
    end
  end

  describe "dotted date" do
    let(:filename) { "2010.02.13.jpg" }

    it "extracts date" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.pattern).to eq(:dotted_date)
    end
  end

  describe "Fuji compact date" do
    let(:filename) { "DSCF20100213.jpg" }

    it "extracts date" do
      expect(result.year).to eq(2010)
      expect(result.month).to eq(2)
      expect(result.day).to eq(13)
      expect(result.pattern).to eq(:compact_date)
    end
  end

  # ── Unix timestamps ─────────────────────────────────────────────────

  describe "Facebook millisecond timestamp" do
    let(:filename) { "FB_IMG_1689350400000.jpg" }

    it "extracts datetime from unix ms" do
      expect(result.year).to eq(2023)
      expect(result.month).to eq(7)
      expect(result.day).to eq(14)
      expect(result.pattern).to eq(:unix_ms)
    end
  end

  # ── Year-only patterns ──────────────────────────────────────────────

  describe "year prefix" do
    let(:filename) { "1972_summer_beach.jpg" }

    it "extracts year only" do
      expect(result.year).to eq(1972)
      expect(result.month).to be_nil
      expect(result.day).to be_nil
      expect(result.pattern).to eq(:year_only)
      expect(result).to be_year_only
    end
  end

  describe "year in scan filename" do
    let(:filename) { "scan_1965.jpg" }

    it "extracts year only" do
      expect(result.year).to eq(1965)
      expect(result.month).to be_nil
      expect(result.pattern).to eq(:year_only)
    end
  end

  describe "year suffix" do
    let(:filename) { "family_photo_1890.jpg" }

    it "extracts year only" do
      expect(result.year).to eq(1890)
      expect(result.pattern).to eq(:year_only)
    end
  end

  # ── Helper methods ──────────────────────────────────────────────────

  describe "Result helper methods" do
    let(:filename) { "IMG_20200615_143052.jpg" }

    it "#date returns a Date" do
      expect(result.date).to eq(Date.new(2020, 6, 15))
    end

    it "#time returns a formatted time string" do
      expect(result.time).to eq("14:30:52")
    end

    it "#datetime returns a Time" do
      expect(result.datetime).to eq(Time.new(2020, 6, 15, 14, 30, 52))
    end

    it "#date_only? is false when time is present" do
      expect(result).not_to be_date_only
    end

    it "#year_only? is false when month is present" do
      expect(result).not_to be_year_only
    end
  end

  # ── Edge cases & validation ─────────────────────────────────────────

  describe "invalid full dates fall back to year_only" do
    it "extracts just year from month 13" do
      result = described_class.call("2020-13-01.jpg")
      expect(result.year).to eq(2020)
      expect(result.month).to be_nil
      expect(result.pattern).to eq(:year_only)
    end

    it "extracts just year from day 32" do
      result = described_class.call("2020-01-32.jpg")
      expect(result.year).to eq(2020)
      expect(result.month).to be_nil
      expect(result.pattern).to eq(:year_only)
    end

    it "extracts just year from Feb 30" do
      result = described_class.call("2020-02-30.jpg")
      expect(result.year).to eq(2020)
      expect(result.month).to be_nil
      expect(result.pattern).to eq(:year_only)
    end
  end

  describe "rejects non-date numbers" do
    it "rejects random 4-digit numbers outside year range" do
      expect(described_class.call("IMG_0001.jpg")).to be_nil
    end

    it "rejects sequence numbers like DSC_0042" do
      expect(described_class.call("DSC_0042.jpg")).to be_nil
    end
  end

  describe "no date in filename" do
    it "returns nil for plain filename" do
      expect(described_class.call("my_photo.jpg")).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.call("")).to be_nil
    end

    it "returns nil for nil" do
      expect(described_class.call(nil)).to be_nil
    end
  end

  describe "strips file extension" do
    let(:filename) { "2010-02-13.jpeg" }

    it "handles various extensions" do
      expect(result.year).to eq(2010)
    end
  end

  describe "handles paths" do
    let(:filename) { "/uploads/photos/IMG_20200615_143052.jpg" }

    it "extracts from basename" do
      expect(result.year).to eq(2020)
      expect(result.month).to eq(6)
    end
  end
end
