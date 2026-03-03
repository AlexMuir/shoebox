class LocationHierarchyService < ApplicationService
  HIERARCHY_TYPES = %w[
    country
    administrative_area_level_1
    locality
    sublocality
    route
    street_address
  ].freeze

  def initialize(family, place_details)
    @family = family
    @place_details = place_details
  end

  def call
    ActiveRecord::Base.transaction do
      parent = nil
      components = extract_hierarchy_components(@place_details[:address_components])

      components[0...-1].each do |component|
        parent = find_or_create_parent(component[:name], parent)
      end

      create_or_find_leaf(parent)
    end
  end

  private

  def extract_hierarchy_components(address_components)
    components = Array(address_components).filter_map do |component|
      type = Array(component["types"]).find { |value| HIERARCHY_TYPES.include?(value) }
      next unless type

      { name: component["longText"], type: type }
    end

    components.sort_by { |component| HIERARCHY_TYPES.index(component[:type]) || 999 }
  end

  def find_or_create_parent(name, parent)
    scope = @family.locations
    existing = if parent
      parent.children.find_by(name: name)
    else
      scope.roots.find_by(name: name)
    end
    return existing if existing

    location = scope.build(name: name)
    location.parent = parent
    location.save!
    location
  rescue ActiveRecord::RecordNotUnique
    if parent
      parent.children.find_by!(name: name)
    else
      scope.roots.find_by!(name: name)
    end
  end

  def create_or_find_leaf(parent)
    leaf = @family.locations.find_by(google_place_id: @place_details[:place_id])
    if leaf
      leaf.update!(parent: parent) if leaf.parent_id != parent&.id
      return leaf
    end

    leaf = @family.locations.build(
      name: @place_details[:name],
      google_place_id: @place_details[:place_id]
    )
    leaf.parent = parent

    populate_address_fields(leaf)
    leaf.save!
    leaf
  rescue ActiveRecord::RecordNotUnique
    @family.locations.find_by!(google_place_id: @place_details[:place_id])
  end

  def populate_address_fields(location)
    components = Array(@place_details[:address_components])
    street_address = components.find { |component| component.fetch("types", []).include?("street_address") }
    locality = components.find { |component| component.fetch("types", []).include?("locality") }
    region = components.find { |component| component.fetch("types", []).include?("administrative_area_level_1") }
    postal_code = components.find { |component| component.fetch("types", []).include?("postal_code") }
    country = components.find { |component| component.fetch("types", []).include?("country") }

    location.address_line_1 = street_address&.dig("longText")
    location.city = locality&.dig("longText")
    location.region = region&.dig("longText")
    location.postal_code = postal_code&.dig("longText")
    location.country = country&.dig("longText")
    location.latitude = @place_details[:lat]
    location.longitude = @place_details[:lng]
  end
end
