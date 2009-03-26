#!/usr/bin/env ruby

$KCODE='u'

require 'enumerator'
require 'fastercsv'

CSV_OPTIONS = {
  :col_sep => "\t",
  :headers => %w(geonameid name asciiname alternatenames latitude longitude feature_class feature_code country_code cc2 admin1_code admin2_code admin3_code admin4_code population elevation gtopo30 timezone modification_date),
  :quote_char => '$', # bogus character
}

CSV_WRITE_OPTIONS = {
  :col_sep => "\t"
}


FasterCSV.open('cities1000.txt', 'rb', CSV_OPTIONS) do |csv|
  FasterCSV.open('cities1000-filtered.txt', 'wb', CSV_WRITE_OPTIONS) do |wcsv|
    csv.each do |row|
      wcsv << [row['geonameid'], row['name'], row['latitude'], row['longitude'], row['country_code']]
    end
  end
end
