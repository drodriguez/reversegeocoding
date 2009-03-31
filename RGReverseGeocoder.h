//
//  RGReverseGeocoder.h
//  ReverseGeocoding
//
//  Created by Daniel Rodríguez Troitiño on 27/03/09.
//  Copyright 2009 Daniel Rodríguez Troitiño.
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import <CoreLocation/CoreLocation.h>

/**
 * A RGReverseGeocoder looks for places given a coordinate pair.
 * It uses a database to find nearby places to the provider coordinate.
 */
@interface RGReverseGeocoder : NSObject {
 @private
  /** Database path */
  NSString *databasePath_;
  /** Level of recursion of the Hilbert curve to generate the sector of the
   database. Default is 10. */
  int level_;
  /** Number of rows or columns in the map. It will be 2^level_. */
  int mapDimension_;
  /** Schema version of the database */
  int schemaVersion_;
  /** Version of the database */
  NSString *databaseVersion_;
  /** Database handler */
  sqlite3 *database_;
}

/**
 * Returns the shared instance of the RGReverseGeocoder.
 * You can have more than one geocoder, each one looking at a different
 * database, using the initWithDatabase message. This is the easy and more
 * useful way.
 * You probably want to run setupDatabase message at least when your application
 * is first run, for this methos to work.
 *
 * @returns The shared instance of the RGReverseGeocoder or nil.
 */
+ (id)sharedGeocoder;

/**
 * Creates a new instance of the RGReverseGeocoder which make its lookups in the
 * specified database.
 *
 * @returns A instance of RGReverseGeocoder or nil.
 */
- (id)initWithDatabase:(NSString *)databasePath;

/**
 * Returns the most probable location for a geographical location.
 * This method looks for places in the same sector as the coordinates provided
 * and its neighbours, then calculates the place with minumun distance.
 *
 * @return A string in the format "City, Country" or "latitude, longitude" if
 *         none found.
 */
- (NSString *)placeForLocation:(CLLocation *)location;

/**
 * Same as the placeForLocation: method, but using latitude and longitude.
 *
 * @return A string in the format "City, Country" or "latitude, longitude" if
 *         none found.
 */
- (NSString *)placeForLatitude:(double)latitude longitude:(double)longitude;

/**
 * Setup the default database from the application resources.
 * This message will copy the compressed database in the application bundle into
 * its uncompressed default location if it is not already there or is not the
 * same version bundle with the application.
 *
 * @returns NO if the copy can not be completed, or YES otherwise.
 */
+ (BOOL)setupDatabase;

@end
