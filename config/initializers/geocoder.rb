Geocoder.configure(
  lookup: :nominatim,
  use_https: true,
  http_headers: { "User-Agent" => "Photos App (dev)" },
  timeout: 5
)
