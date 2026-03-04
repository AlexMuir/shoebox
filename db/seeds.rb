puts "Seeding Photos database..."

# Create a family
family = Family.find_or_create_by!(name: "The Muirs")

# Create users
alex = User.find_or_create_by!(email: "alex@example.com") do |u|
  u.name = "Alex Muir"
end

robin = User.find_or_create_by!(email: "robin@example.com") do |u|
  u.name = "Robin Muir"
end

lindsey = User.find_or_create_by!(email: "lindsey@example.com") do |u|
  u.name = "Lindsey Muir"
end

# Create family memberships
[ alex, robin, lindsey ].each do |user|
  FamilyMembership.find_or_create_by!(family: family, user: user, role: "member")
end

# Create people (who appear in photos)
people_data = [
  { first_name: "Alex", last_name: "Muir", date_of_birth: Date.new(1982, 3, 15), user: alex },
  { first_name: "Robin", last_name: "Muir", date_of_birth: Date.new(1955, 7, 22), user: robin },
  { first_name: "Lindsey", last_name: "Muir", date_of_birth: Date.new(1957, 11, 8), user: lindsey },
  { first_name: "Margaret", last_name: "Muir", date_of_birth: Date.new(1930, 5, 1), date_of_death: Date.new(2015, 12, 3) },
  { first_name: "James", last_name: "Muir", date_of_birth: Date.new(1928, 9, 14), date_of_death: Date.new(2010, 4, 20) },
  { first_name: "Sarah", last_name: "Muir", date_of_birth: Date.new(1985, 1, 30) },
  { first_name: "David", last_name: "Campbell", date_of_birth: Date.new(1980, 6, 12) }
]

people = people_data.map do |data|
  Person.find_or_create_by!(family: family, first_name: data[:first_name], last_name: data[:last_name]) do |p|
    p.date_of_birth = data[:date_of_birth]
    p.date_of_death = data[:date_of_death]
    p.user = data[:user]
    p.bio = data[:bio]
  end
end

# Create locations
uk = Location.find_or_create_by!(family: family, name: "United Kingdom") do |l|
  l.country = "United Kingdom"
end
scotland = Location.find_or_create_by!(family: family, name: "Scotland") do |l|
  l.parent = uk
end
edinburgh = Location.find_or_create_by!(family: family, name: "Edinburgh") do |l|
  l.city = "Edinburgh"
  l.parent = scotland
end
chester_zoo = Location.find_or_create_by!(family: family, name: "Chester Zoo") do |l|
  l.city = "Chester"
  l.country = "United Kingdom"
  l.parent = uk
end
kenya = Location.find_or_create_by!(family: family, name: "Kenya") do |l|
  l.country = "Kenya"
end

# Create events
events_data = [
  { title: "Summer Holiday 1984", date_type: "season", year_from: 1984, season_from: "summer", location: chester_zoo },
  { title: "Christmas 1990", date_type: "month", year_from: 1990, month_from: 12, location: edinburgh },
  { title: "Wedding Day", date_type: "exact", year_from: 1980, month_from: 6, day_from: 14, location: edinburgh },
  { title: "Kenya Safari", date_type: "year", year_from: 1995, location: kenya },
  { title: "Grandma's 80th Birthday", date_type: "exact", year_from: 2010, month_from: 5, day_from: 1 }
]

events = events_data.map do |data|
  Event.find_or_create_by!(family: family, title: data[:title]) do |e|
    e.date_type = data[:date_type]
    e.year_from = data[:year_from]
    e.month_from = data[:month_from]
    e.day_from = data[:day_from]
    e.season_from = data[:season_from]
    e.location = data[:location]
  end
end

puts "Seeded: #{Family.count} families, #{User.count} users, #{Person.count} people, #{Location.count} locations, #{Event.count} events"
puts "Done! Sign in with: alex@example.com, robin@example.com, or lindsey@example.com"
