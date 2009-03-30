Reverse Geocoding
=================

This project a Objective-C class (aim to be used on the iPhone) to include in
your application a reverse geocoding system. Included in the project there is
also a Thor <http://github.com/wycats/thor> script for downloading the cities
database and transforming it into a suitable format for the iPhone.

What's a “reverse geocoding” system?
------------------------------------

As Wikipedia says <http://en.wikipedia.org/wiki/Geocoding>:

> Geocoding is the process of finding associated geographic coordinates … from
> other geographic data, such as street addresses, or zip codes. …
>
> Reverse Geocoding is the opposite: finding an associated textual location
> such a street address, from geographic coordinates.

How do I use it
===============

The project includes a script for Thor <http://github.com/wycats/thor> that
tries to make the use of the project classes and the needed resources as
easy as I can.

This project tries to leverage the tools include in Mac OS X 10.5, but there
are some steps you have to do before using this script. So open your Terminal
and type the following (except the dollar sign):

        $ gem install thor sqlite3-ruby fastercsv

After Thor installation you have to install this project Thor script into your
system:

        $ thor install http://github.com/drodriguez/reversegeocoding/blob/master/geocoder.thor?raw=true

When asked, you should say “y” to the question “Do you wish to continue?” and
provide “geocoder” as name for the script in your system.

Once installed you can use Thor anywhere in your system to access the geocoder
tasks. You can get a list of the task typing the following:

        $ thor list geocoder

And you can update the Thor script easily by:

        $ thor update geocoder

The easiest way to use the reverse geocoding system is to use the defaults,
download all (code and databases), and create the SQLite database and the
auxiliary files.

        $ thor geocoder:download all
        $ thor geocoder:database

Then in your application include the following files:

- <code>RGReverseGeocoder.h</code>
- <code>RGReverseGeocoder.m</code>
- <code>RGConfig.h</code>
- <code>geodata.sqlite.gz</code>
- <code>geodata.sqlite.plist</code>

And also add <code>libsqlite3.dylib</code>, <code>libz.dylib</code> and
<code>CoreLocation.framework</code> to your application.

Then at the start of your application call to:

        [RGReverseGeocoder setupDatabase];

And when you need to get a place from a location:

        [[RGReverseGeocoder sharedGeocoder] placeForLocation:myLocation];

If you need more help look at help from the Thor script, the documentation
of the source code and the example project included in this Git repository.

Credits
=======

Author: Daniel Rodríguez Troitiño <drodrigueztroitino@yahoo.es>

This project could not have been done without the free data provided by
GeoNames <http://geonames.org>. GeoNames data is licensed under a Creative
Commons Attribution 3.0 License <http://creativecommons.org/licenses/by/3.0/>.
The data is provided "as is" without warranty or any representation of
accuracy, timeliness or completeness.

There is a small “inspiration” on some parts of SQLite Persistent Objects for
Cocoa and Cocoa Touch <http://code.google.com/p/sqlitepersistentobjects>.

There is also a method adapted from Figure 14-10 of Hacker's Delight by Henry
S. Warren <http://www.hackersdelight.org/>.