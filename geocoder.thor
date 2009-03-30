$KCODE='u'

class Geocoder < Thor
  GEONAMES_DUMP_BASE_URL = 'http://download.geonames.org/export/dump/'
  GEONAMES_CITIES_BASE_NAME = 'cities%size%.zip'
  GEONAMES_COUNTRY_INFO = 'countryInfo.txt'
  
  desc "download all|code|cities|countries", "Download the code or the GeoNames database dump of the specified size. Possible sizes are 1000, 5000 and 15000."
  method_options :size => 5000, :dest => :optional
  def download(what)
    case what.downcase
    when 'code'
      nil
    when 'cities'
      download_cities(options['size'], options['dest'])
    when 'countries'
      download_countries(dest)
    when 'all'
      nil
    else
      task = self.class.tasks['download']
      puts task.formatted_usage(false)
      puts task.description
    end
  end
  
  
private
  def download_cities(size, dest)
    size = size.to_s
    filename = GEONAMES_CITIES_BASE_NAME.gsub('%size%', size)
    dest = dest.nil? ? filename : dest
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)    
  end
  
  def download_countries(dest)
    filename = GEONAMES_COUNTRY_INFO
    dest = dest.nil? ? filename : dest
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)
  end
  
  def download_url(url, dest)
    puts "Downloading #{url} -> #{dest}"
    `curl -o "#{dest}" "#{url}"`
  end
end