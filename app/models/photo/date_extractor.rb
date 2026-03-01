# frozen_string_literal: true

# Extracts date/time information from photo filenames.
#
# Cameras, phones, scanners, and social media apps embed dates in filenames
# using many different formats. This class attempts to parse them all,
# returning a structured result with year, month, day, hour, minute, second
# and a confidence level.
#
# Usage:
#   result = Photo::DateExtractor.call("IMG_20200615_143052.jpg")
#   result.year    # => 2020
#   result.month   # => 6
#   result.day     # => 15
#   result.time    # => "14:30:52"
#   result.source  # => :filename
#   result.pattern # => :android_standard
#
class Photo::DateExtractor
  Result = Struct.new(:year, :month, :day, :hour, :minute, :second, :pattern, keyword_init: true) do
    def date
      return nil unless year
      Date.new(year, month || 1, day || 1)
    rescue Date::Error
      nil
    end

    def time
      return nil unless hour
      format("%02d:%02d:%02d", hour, minute || 0, second || 0)
    end

    def datetime
      return nil unless year && month && day && hour
      Time.new(year, month, day, hour, minute || 0, second || 0) rescue nil
    end

    def date_only?
      year.present? && hour.nil?
    end

    def year_only?
      year.present? && month.nil?
    end
  end

  # Ordered by specificity — most specific patterns first.
  # Each entry: [regex, pattern_name, lambda returning Result]
  PATTERNS = [
    # ── Full datetime patterns (YYYY + MM + DD + HH + MM + SS) ──────────

    # Underscored: 2010_02_13_09_57_10.jpg
    [
      /(?:^|[_\-\s])(\d{4})_(\d{2})_(\d{2})_(\d{2})_(\d{2})_(\d{2})(?:[_.\-]|$)/,
      :underscored_iso,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, hour: m[4].to_i, minute: m[5].to_i, second: m[6].to_i, pattern: :underscored_iso) }
    ],

    # Telegram: photo_2023-06-15_14-20-33.jpg (underscore between date and time)
    [
      /photo[_](\d{4})-(\d{2})-(\d{2})[_](\d{2})-(\d{2})-(\d{2})/,
      :telegram,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, hour: m[4].to_i, minute: m[5].to_i, second: m[6].to_i, pattern: :telegram) }
    ],

    # Signal: signal-2023-06-15-142033.jpg or signal-2023-06-15-14-20-33.jpg
    [
      /signal-(\d{4})-(\d{2})-(\d{2})-(\d{2})-?(\d{2})-?(\d{2})/,
      :signal,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, hour: m[4].to_i, minute: m[5].to_i, second: m[6].to_i, pattern: :signal) }
    ],

    # Dashed datetime: 2010-02-13_09-57-10.jpg or 2010-02-13-09-57-10.jpg
    [
      /(\d{4})-(\d{2})-(\d{2})[_\-](\d{2})-(\d{2})-(\d{2})/,
      :dashed_iso,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, hour: m[4].to_i, minute: m[5].to_i, second: m[6].to_i, pattern: :dashed_iso) }
    ],

    # macOS screenshot: Screenshot 2023-01-15 at 14.20.33.png
    [
      /(\d{4})-(\d{2})-(\d{2})\s+at\s+(\d{1,2})\.(\d{2})\.(\d{2})/,
      :macos_screenshot,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, hour: m[4].to_i, minute: m[5].to_i, second: m[6].to_i, pattern: :macos_screenshot) }
    ],

    # Compact with prefix: IMG_20200615_143052.jpg, PXL_20210415_180322045.jpg,
    # Screenshot_20230115-142033.jpg, DSC_20100213_095710.jpg
    [
      /(\d{4})(\d{2})(\d{2})[_\-](\d{2})(\d{2})(\d{2})/,
      :compact_datetime,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, hour: m[4].to_i, minute: m[5].to_i, second: m[6].to_i, pattern: :compact_datetime) }
    ],

    # Dotted time: 2010-02-13 09.57.10.jpg
    [
      /(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2})\.(\d{2})\.(\d{2})/,
      :dashed_dotted_time,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, hour: m[4].to_i, minute: m[5].to_i, second: m[6].to_i, pattern: :dashed_dotted_time) }
    ],


    # ── Date-only patterns (YYYY + MM + DD, no time) ───────────────────

    # WhatsApp: IMG-20200615-WA0023.jpg
    [
      /IMG-(\d{4})(\d{2})(\d{2})-WA/,
      :whatsapp,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, pattern: :whatsapp) }
    ],

    # Compact date only: DSCF20100213.jpg, 20100213.jpg, or prefixed variants
    [
      /(?:^|[A-Za-z_\-])(\d{4})(\d{2})(\d{2})(?:[_.\-\s]|$)/,
      :compact_date,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, pattern: :compact_date) }
    ],

    # Dashed date: 2010-02-13.jpg, photo-2010-02-13.jpg
    [
      /(\d{4})-(\d{2})-(\d{2})/,
      :dashed_date,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, pattern: :dashed_date) }
    ],

    # Underscored date: 2010_02_13.jpg
    [
      /(\d{4})_(\d{2})_(\d{2})(?:[_.\-\s]|$)/,
      :underscored_date,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, pattern: :underscored_date) }
    ],

    # Slashed date in filename (rare but happens): 2010.02.13.jpg
    [
      /(\d{4})\.(\d{2})\.(\d{2})/,
      :dotted_date,
      ->(m) { Result.new(year: m[1].to_i, month: m[2].to_i, day: m[3].to_i, pattern: :dotted_date) }
    ],

    # ── Unix timestamp patterns ────────────────────────────────────────

    # Facebook: FB_IMG_1689234567890.jpg (13-digit ms timestamp)
    [
      /(\d{13})(?:[_.\-]|$)/,
      :unix_ms,
      ->(m) {
        time = Time.at(m[1].to_i / 1000.0).utc
        Result.new(year: time.year, month: time.month, day: time.day, hour: time.hour, minute: time.min, second: time.sec, pattern: :unix_ms)
      }
    ],

    # Unix timestamp (10-digit seconds)
    [
      /(?:^|[_\-])(\d{10})(?:[_.\-]|$)/,
      :unix_sec,
      ->(m) {
        time = Time.at(m[1].to_i).utc
        Result.new(year: time.year, month: time.month, day: time.day, hour: time.hour, minute: time.min, second: time.sec, pattern: :unix_sec)
      }
    ],

    # ── Year-only patterns (least specific, checked last) ──────────────

    # Year prefix or suffix: 1972_summer_beach.jpg, scan_1965.jpg, 1890s_family.jpg
    [
      /(?:^|[_\-\s])(\d{4})(?:[_\-\s.]|$)/,
      :year_only,
      ->(m) { Result.new(year: m[1].to_i, pattern: :year_only) }
    ]
  ].freeze

  # Reasonable year range for photos — excludes random 4-digit numbers
  VALID_YEAR_RANGE = (1826..Date.current.year + 1).freeze

  def self.call(filename)
    new(filename).extract
  end

  def initialize(filename)
    @filename = filename.to_s
    @basename = File.basename(@filename, File.extname(@filename))
  end

  def extract
    PATTERNS.each do |regex, _name, builder|
      match = @basename.match(regex)
      next unless match

      result = builder.call(match)
      next unless valid_result?(result)

      return result
    end

    nil
  end

  private

  def valid_result?(result)
    return false unless result&.year
    return false unless VALID_YEAR_RANGE.cover?(result.year)
    return false if result.month && !result.month.between?(1, 12)
    return false if result.day && !result.day.between?(1, 31)
    return false if result.hour && !result.hour.between?(0, 23)
    return false if result.minute && !result.minute.between?(0, 59)
    return false if result.second && !result.second.between?(0, 59)

    # Extra check: if we have month+day, verify the date is real
    if result.year && result.month && result.day
      Date.new(result.year, result.month, result.day)
    end

    true
  rescue Date::Error
    false
  end
end
