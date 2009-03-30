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
  method_options :from => 'cities5000.txt', :to => 'geodata.sqlite', :countries => 'countryInfo.txt'
  def database(size = 5000)
    # TODO
  end
  
  desc "compress", "Compress the SQLite database using Gzip"
  method_options :from => 'geodata.sqlite', :to => 'geodata.sqlite.gz'
  def compress
    `gzip < "#{options['from']}" > "#{options['to']}"`
  end
  
private
  def download_cities(size, dest = nil)
    size = size.to_s
    filename = GEONAMES_CITIES_BASE_NAME.gsub('%size%', size)
    dest = dest.nil? ? filename : dest
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)
    `unzip "#{dest}"`
  end
  
  def download_countries(dest = nil)
    filename = GEONAMES_COUNTRY_INFO
    dest = dest.nil? ? filename : dest
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)
  end
  
  def download_code(dest = nil)
    # TODO
  end
  
  def download_url(url, dest)
    puts "Downloading #{url} -> #{dest}"
    `curl -o "#{dest}" "#{url}"`
  end
end