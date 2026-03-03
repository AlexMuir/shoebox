require "net/http"
require "json"

class GooglePlacesService < ApplicationService
  AUTOCOMPLETE_URL = "https://places.googleapis.com/v1/places:autocomplete"
  DETAILS_BASE_URL = "https://places.googleapis.com/v1/places"
  FIELD_MASK = "id,displayName,formattedAddress,location,addressComponents"
  TIMEOUT = 3

  def autocomplete(query, session_token)
    return [] unless api_key_present?

    uri = URI(AUTOCOMPLETE_URL)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = { input: query, sessionToken: session_token }.to_json

    response = make_request(uri, request)
    return [] unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    suggestions = body.fetch("suggestions", [])

    suggestions.filter_map do |suggestion|
      prediction = suggestion["placePrediction"]
      next unless prediction

      {
        place_id: prediction["placeId"],
        description: prediction.dig("text", "text")
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error(e.message)
    []
  end

  def place_details(place_id, session_token)
    return nil unless api_key_present?

    uri = URI("#{DETAILS_BASE_URL}/#{place_id}")
    uri.query = URI.encode_www_form(sessionToken: session_token)
    request = Net::HTTP::Get.new(uri)
    request["X-Goog-FieldMask"] = FIELD_MASK

    response = make_request(uri, request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    {
      place_id: body["id"],
      name: body.dig("displayName", "text"),
      lat: body.dig("location", "latitude"),
      lng: body.dig("location", "longitude"),
      address_components: body.fetch("addressComponents", []),
      formatted_address: body["formattedAddress"]
    }
  rescue JSON::ParserError => e
    Rails.logger.error(e.message)
    nil
  end

  private

  def api_key
    Rails.application.credentials.dig(:google, :places_api_key)
  end

  def api_key_present?
    return true if api_key.present?

    Rails.logger.warn("Google Places API key missing")
    false
  end

  def make_request(uri, request)
    request["X-Goog-Api-Key"] = api_key

    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: TIMEOUT,
      read_timeout: TIMEOUT
    ) do |http|
      http.request(request)
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, StandardError => e
    Rails.logger.error(e.message)
    nil
  end
end
