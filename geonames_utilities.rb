#!/usr/bin/env ruby

$KCODE='u'

require 'enumerator'
require 'fastercsv'
require 'sqlite3'

CSV_OPTIONS = {
  :col_sep => "\t",
}

CSV_WRITE_OPTIONS = {
  :col_sep => "\t",
}

PLACES_FILE = 'cities1000.txt'
PLACES_OPTIONS = {
  :headers => %w(geonameid name asciiname alternatenames latitude longitude feature_class feature_code country_code cc2 admin1_code admin2_code admin3_code admin4_code population elevation gtopo30 timezone modification_date),
  :quote_char => '$', # bogus character
}

COUNTRIES_FILE = 'countryInfo.txt'
COUNTRIES_OPTIONS = {
  :headers => %w(ISO ISO3 ISO_numeric fips country capital area population continent tld currency_code currency_name phone postal_code_format postal_code_regex languages geonameid neighbours equivalent_fips_code),
}

DATABASE_FILE = ARGV[0] || 'geodata.sqlite'

FORCE_DROP = true



# Create the database
db = SQLite3::Database.new(DATABASE_FILE)

# Create the countries table
db.execute("DROP TABLE IF EXISTS countries") if FORCE_DROP
db.execute(<<SQL)
CREATE TABLE IF NOT EXISTS countries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  iso TEXT NOT NULL,
  name TEXT NOT NULL,
  geonameid INTEGER UNIQUE NOT NULL
)
SQL
db.execute("CREATE INDEX IF NOT EXISTS countries_iso_idx ON countries (iso)")
db.execute("DELETE FROM countries")

# Create the places table
db.execute("DROP TABLE IF EXISTS places") if FORCE_DROP
db.execute(<<SQL)
CREATE TABLE IF NOT EXISTS places (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  geonameid INTEGER UNIQUE NOT NULL,
  name TEXT NOT NULL,
  latitude TEXT NOT NULL,
  longitude TEXT NOT NULL,
  sector INTEGER NOT NULL,
  country_id INTEGER NOT NULL REFERENCES coutries (id)
)
SQL
db.execute("CREATE INDEX IF NOT EXISTS places_sector_idx ON places (sector)")
db.execute("DELETE FROM places")

# Prepare the insert statements
country_insert = db.prepare("INSERT INTO countries (iso, name, geonameid) VALUES (:iso, :name, :geonameid)")
place_insert = db.prepare("INSERT INTO places (geonameid, name, latitude, longitude, sector, country_id) VALUES (:geonameid, :name, :latitude, :longitude, 0, :country_id)")

countries = Hash.new
# Remember stripping comments from the countries file
FasterCSV.open(COUNTRIES_FILE, 'rb', CSV_OPTIONS.merge(COUNTRIES_OPTIONS)) do |csv|
  csv.rewind unless csv.to_io.read(3) == "\xef\xbb\xbf" # Skip UTF-8 marker
  csv.each do |row|
    country_insert.execute :iso => row['ISO'], :name => row['country'], :geonameid => row['geonameid'].to_i
    countries[row['ISO']] = db.last_insert_row_id
  end
end

FasterCSV.open('cities1000.txt', 'rb', CSV_OPTIONS.merge(PLACES_OPTIONS)) do |csv|
  csv.rewind unless csv.to_io.read(3) == "\xef\xbb\xbf" # Skip UTF-8 marker
  csv.each do |row|
    country_id = countries[row['country_code']]
    puts "<#{row['country_code']}>" if country_id.nil?
    place_insert.execute :geonameid => row['geonameid'], :name => row['name'], :latitude => row['latitude'], :longitude => row['longitude'], :country_id => country_id
  end
end

db.execute('VACUUM')
db.close
