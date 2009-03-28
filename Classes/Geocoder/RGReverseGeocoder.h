//
//  RGReverseGeocoder.h
//  ReverseGeocoding
//
//  Created by Daniel Rodríguez Troitiño on 27/03/09.
//  Copyright 2009 Daniel Rodríguez Troitiño. All rights reserved.
//

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
  /** Database handler */
  sqlite3 *database_;
}

@property (nonatomic, assign) int level;

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
 * @return A string in the format "City, Country" or nil if none found.
 */
- (NSString *)placeForLocation:(CLLocation *)location;

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
