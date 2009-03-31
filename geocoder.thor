# Copyright 2009 Daniel Rodríguez Troitiño.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

$KCODE='u'



class Geocoder < Thor
  GEONAMES_DUMP_BASE_URL = 'http://download.geonames.org/export/dump/'
  GEONAMES_CITIES_BASE_NAME = 'cities%size%.zip'
  GEONAMES_COUNTRY_INFO = 'countryInfo.txt'
  
  CSV_OPTIONS = { :col_sep => "\t" }
  CITIES_CSV_OPTIONS = {
    :headers => %w(geonameid name asciiname alternatenames latitude longitude feature_class feature_code country_code cc2 admin1_code admin2_code admin3_code admin4_code population elevation gtopo30 timezone modification_date),
    :quote_char => '$', # bogus character
  }
  COUNTRIES_CSV_OPTIONS = {
    :headers => %w(ISO ISO3 ISO_numeric fips country capital area population continent tld currency_code currency_name phone postal_code_format postal_code_regex languages geonameid neighbours equivalent_fips_code),
  }
  
  DATABASE_SCHEMA_VERSION = 1
  
  CODE_BASE_URL = "http://github.com/drodriguez/reversegeocoding/blob/master/%file%?raw=true"
  RG_M_FILE = "RGReverseGeocoder.m"
  RG_H_FILE = "RGReverseGeocoder.h"
  
  desc "download all|code|cities|countries", "Download the code or the GeoNames database dump of the specified size. Possible sizes are 1000, 5000 and 15000."
  method_options :size => 5000, :dest => :optional
  def download(what)
    case what.downcase
    when 'code'
      download_code(options['dest'])
    when 'cities'
      download_cities(options['size'], options['dest'])
    when 'countries'
      download_countries(options['dest'])
    when 'all'
      download_cities(options['size'])
      download_countries
      download_code
    else
      task = self.class.tasks['download']
      puts task.formatted_usage(false)
      puts task.description
    end
  end
  
  desc "database", "Read GeoNames database dumps and transforms it into a SQLite database."
  method_options :from => 'cities5000.txt', :to => 'geodata.sqlite', :countries => 'countryInfo.txt', :level => 10
  def database(size = 5000)
    from = options['from']
    to = options['to']
    countries = options['countries']
    level = options['level']
    
    require 'FasterCSV'
    require 'sqlite3'
    
    puts "Creating database..."
    db = create_database(to)
    create_countries_table(db)
    create_cities_table(db)
    puts "Inserting countries data..."
    countries_ids = insert_countries(db, countries)
    puts "Inserting cities data (this could take a while)..."
    insert_cities(db, from, level, countries_ids)
    close_database(db)
    puts "Creating metadata file..."
    create_plist_file(to, from, level)
    puts "Creating RGConfig.h file..."
    create_header_file(to, from, level)
    puts "Compressing database..."
    `gzip < "#{options['to']}" > "#{options['to']}.gz"`
  end
  
private
  def download_cities(size, dest = nil)
    size = size.to_s
    filename = GEONAMES_CITIES_BASE_NAME.gsub('%size%', size)
    dest = dest.nil? ? filename : dest
    dest = File.join(dest, filename) if File.directory?(dest)
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)
    `unzip -o "#{dest}"`
  end
  
  def download_countries(dest = nil)
    filename = GEONAMES_COUNTRY_INFO
    dest = dest.nil? ? filename : dest
    dest = File.join(dest, filename) if File.directory?(dest)
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)
  end
  
  def download_code(dest = nil)
    dest = dest.nil? ? '.' : dest
    dest = File.dirname(dest) unless File.directory?(dest)
    download_url(CODE_BASE_URL.gsub('%file%', RG_M_FILE), File.join(dest, RG_M_FILE))
    download_url(CODE_BASE_URL.gsub('%file%', RG_H_FILE), File.join(dest, RG_H_FILE))
  end
  
  def download_url(url, dest)
    puts "Downloading #{url} -> #{dest}"
    `curl -o "#{dest}" "#{url}"`
  end
  
  
  
  # Database functions
  
  def sector_xy(lat, lon, r = 10)
    # We suppose latitude is also [-180,180] so the sector are squares
    lat += 180
    lon += 180

    [(2**r*lat/360.0).floor, (2**r*lon/360.0).floor]
  end
  
  def hilbert_distance(x, y, r = 10)
    # from Hacker's delight Figure 14-10
    s = 0

    r.downto(0) do |i|
      xi = (x >> i) & 1 # Get bit i of x
      yi = (y >> i) & 1 # Get bit i of y

      if yi == 0
        temp = x         # Swap x and y and,
        x = y ^ (-xi)    # if xi = 1,
        y = temp ^ (-xi) # complement them.
      end
      s = 4*s + 2*xi + (xi ^ yi) # Append two bits to s.
    end

    s
  end
  
  def create_database(to)
    if File.exists?(to)
      puts "File '#{to}' already exist. Please move away the file or remove it."
      exit
    end
    
    SQLite3::Database.new(to)
  end
  
  def create_countries_table(db)
    db.execute(<<-SQL)
    CREATE TABLE countries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT
    )
    SQL
  end
  
  def create_cities_table(db)
    db.execute(<<-SQL)
    CREATE TABLE cities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      sector INTEGER NOT NULL,
      country_id INTEGER NOT NULL
    )
    SQL
    db.execute("CREATE INDEX IF NOT EXISTS cities_sector_idx ON cities (sector)")
  end
  
  def insert_countries(db, countries)
    ids = Hash.new
    country_insert = db.prepare("INSERT INTO countries (name) VALUES (:name)")
    open(countries, 'rb') do |io|
      io.rewind unless io.read(3) == "\xef\xbb\xbf" # Skip UTF-8 marker
      io.readline while io.read(1) == '#' # Skip comments at the start of the file
      io.seek(-1, IO::SEEK_CUR) # Unread the last character that wasn't '#'
      csv = FasterCSV.new(io, CSV_OPTIONS.merge(COUNTRIES_CSV_OPTIONS))
      csv.each do |row|
        country_insert.execute :name => row['country']
        ids[row['ISO']] = db.last_insert_row_id
      end
    end
    country_insert.close
    
    ids
  end
  
  def insert_cities(db, from, level, countries_ids)
    city_insert = db.prepare("INSERT INTO cities (name, latitude, longitude, sector, country_id) VALUES (:name, :latitude, :longitude, :sector, :country_id)")
    open(from, 'rb') do |io|
      io.rewind unless io.read(3) == "\xef\xbb\xbf" # Skip UTF-8 marker
      io.readline while io.read(1) == '#' # Skip comments at the start of the file
      io.seek(-1, IO::SEEK_CUR) # Unread the last character that wasn't '#'
      csv = FasterCSV.new(io, CSV_OPTIONS.merge(CITIES_CSV_OPTIONS))
      csv.each do |row|
        country_id = countries_ids[row['country_code']]
        lon, lat = row['longitude'].to_f, row['latitude'].to_f
        x, y = sector_xy(lat, lon, level)
        sector = hilbert_distance(x, y, level)
        city_insert.execute :name => row['name'], :latitude => lat, :longitude => lon, :country_id => country_id, :sector => sector
      end
    end
    
    city_insert.close
  end
  
  def close_database(db)
    db.execute('VACUUM')
    db.close
  end
  
  def create_plist_file(to, from, level)
    require 'osx/cocoa'
    
    db_version = File.mtime(from).strftime('%Y%m%d%H%M%S')
    schema_version = DATABASE_SCHEMA_VERSION
    
    dict = OSX::NSDictionary.dictionaryWithObjects_forKeys(
      [db_version, schema_version, level],
      ['database_version', 'schema_version', 'database_level'])
    dict.writeToFile_atomically(to + ".plist", true)
  end
  
  def create_header_file(to, from, level)
    db_version = File.mtime(from).strftime('%Y%m%d%H%M%S')
    schema_version = DATABASE_SCHEMA_VERSION
    
    open(HEADER_FILE, 'wb') do |io|
      io.write(<<-HEADER)
      #ifndef RGCONFIG
      #define RGCONFIG

      #define DATABASE_VERSION #{db_version}
      #define SCHEMA_VERSION #{schema_version}
      #define DATABASE_LEVEL #{level}
      #define DATABASE_FILENAME @"#{to}"

      #endif
      HEADER
    end
  end
end