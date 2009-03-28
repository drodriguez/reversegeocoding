//
//  RGReverseGeocoder.m
//  ReverseGeocoding
//
//  Created by Daniel Rodríguez Troitiño on 27/03/09.
//  Copyright 2009 Daniel Rodríguez Troitiño. All rights reserved.
//

/*
 * Parts of this file are "inspired" in SQLitePersistentObjects
 * http://code.google.com/p/sqlitepersistentobjects/
 */

#import "RGReverseGeocoder.h"

#define DEFAULT_DATABASE_LEVEL 10
#define DATABASE_SCHEMA_VERSION 1
#define DATABASE_FILENAME @"geodata.sqlite"

#define MAX_DISTANCE_ON_EARTH 21000.0
#define EARTH_RADIUS 6378.0

#define RGLogX(s, ...) NSLog(@"%s -" s, __PRETTY_FUNCTION__, ##__VA_ARGS__)
#if defined(DEBUG)
#  define RGLog(s, ...) RGLogX(s, ##__VA_ARGS__)
#else
#  define RGLog(s, ...)
#endif

/** Shared instance */
static RGReverseGeocoder *sharedInstance = nil;

#pragma mark Private interface
@interface RGReverseGeocoder ()

@property (nonatomic, assign) sqlite3 *database;

/**
 * Init a RGReverseGeocoder with the default database.
 */
- (id)init;

/**
 * Returns the row or column of the sector from the latitude or the longitude.
 */
- (int)sectorFromCoordinate:(double)coordinate;

/**
 * Returns the Hilbert curve distance of a sector.
 */
- (int)hilbertDistanceForRow:(int)row column:(int)column;

@end


#pragma mark Local methods

/**
 * Returns the path of the default database file.
 * This path is <NSApplicationSupportDirectory>/geodata.sqlite.
 */
NSString *defaultDatabaseFile() {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  
  if ([paths count] == 0) {
    RGLogX(@"Application Support directory in User Domain not found.");
    return nil;
  }
  
  NSString defaultPath = [[paths objectAtIndex:0]
                          stringByAppendingPathComponent:DATABASE_FILE];
  
  return defaultPath;
}

/**
 * Check that the database file is current with the actual implementation.
 * This checks against the <databaseFile>.plist that the schema version is
 * supported.
 */
BOOL checkDatabaseFile(NSString *databaseFile) {
  NSString *plistFile = [databaseFile stringByAppendingString:@".plist"];
  
  NSData *metadataData = [NSData dataWithContentsOfFile:plistFile];
  NSString *error;
  NSPropertyListFormat format;
  NSDictionary *metadata =
  (NSDictionary *)[NSPropertyListSerialization
                   propertyListFromData:metadataData
                   mutabilityOption:NSPropertyListImmutable
                   format:&format
                   errorDescription:&error];
  if (!metadata) {
    RGLogX(@"Database metadata failed to load with error '%@'.", error);
    return NO;
  }
  
  NSNumber *databaseSchemaVersion = [metadata objectForKey:@"schema_version"];
  
  return [databaseSchemaVersion intValue] == DATABASE_SCHEMA_VERSION;
}

/**
 * Returns the spherical distance between two points.
 */
double distance(double lat1, double lon1, double lat2, double lon2) {
  /* Convert all to radians */
  lat1 = (lat1/180) * M_PI;
  lon1 = (lon1/180) * M_PI;
  lat2 = (lat2/180) * M_PI;
  lon2 = (lon2/180) * M_PI;
  
  double clat1 = cos(lat1);
  double clon1 = cos(lon1);
  double clat2 = cos(lat2);
  double clon2 = cos(lon2);
  
  double slat1 = sin(lat1);
  double slon1 = sin(lon1);
  double slat2 = sin(lat2);
  double slon2 = sin(lon2);
  
  return EARTH_RADIUS*(acos(clat1*clon1*clat2*clon2) +
                       clat1*slon1*clat2*slon2 +
                       slat1*slat2)
}

@implementation RGReverseGeocoder

@synthesize database = database_;

#pragma mark Class methods
+ (id)sharedGeocoder {
  @synchronized(self) {
    if (sharedInstance == nil) {
      [[self alloc] init];
    }
  }
  
  return sharedInstance;
}

+ (BOOL)setupDatabase {
  // TODO
}

#pragma mark Public instance methods

- (id)initWithDatabase:(NSString *)databaseFile {
  if (self = [super init]) {
    databaseFile_ = [databaseFile copy];
    self.level = DEFAULT_DATABASE_LEVEL;
    
    if (!checkDatabaseFile(databaseFile_)) {
      RGLogX(@"Database schema version for '%@' database differs", databaseFile_);
      [databaseFile_ release];
      return nil;
    }
  }
  
  return self;
}

- (NSString *)placeForLocation:(CLLocation *)location {
  NSString *fallback = [NSString stringWithFormat:@"%f, %f",
                        location.coordinate.latitude,
                        location.coordinate.longitude];
  
  int row = [self sectorFromCoordinate:location.coordinate.latitude];
  int col = [self sectorFromCoordinate:location.coordinate.longitude];
  
  // TODO: Get the eight sectors around the central one
  int sector = [self hilbertDistanceForRow:row column:col];
  
  NSString *query = @"SELECT places.name, country.name, latitude, longitude "
    "FROM places JOIN countries ON places.country_id = country.id "
    "WHERE sector = ?";
  
  sqlite3 *db = self.database;
  sqlite3_stmt *stmt;
  if (sqlite3_prepare_v2(db, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
    RGLog(@"Can not prepare SQlite statement with error '%s'.", sqlite3_errmsg(db));
    return fallback;
  }
  if (sqlite3_bind_int(stmt, 1, sector) != SQLITE_OK) {
    RGLog(@"Can not bind SQLite parameter with error '%s'.", sqlite3_errmsg(db));
    sqlite3_finalize(stmt);
    return fallback;
  }
  
  NSString *name = nil, *country = nil;
  double minDistance = MAX_DISTANCE_ON_EARTH;
  while (sqlite3_step(stmt) == SQLITE_ROW) {
    double lat = sqlite3_column_double(stmt, 2);
    double lon = sqlite3_column_double(stmt, 3);
    double distance = distance(location.coordinate.latitude,
                               location.coordinate.longitude,
                               lat,
                               lon);
    if (distance < minDistance) {
      minDistance = distance;
      
      if (name) [name release];
      const char *text = (const char *)sqlite3_column_text(stmt, 0);
      if (text == nil) {
        RGLog(@"Row without name!?");
        sqlite3_finalize(stmt);
        if (country) [country release];
        return fallback;
      }
      name = [NSString stringWithUTF8String:text];
      
      if (country) [country release];
      text = (const char *)sqlite3_column_text(stmt, 1);
      if (text == nil) {
        RGLog(@"Row without country!?");
        sqlite3_finalize(stmt);
        if (name) [name release];
        return fallback;
      }
      country = [NSString stringWithUTF8String:text];
    }
  }
  sqlite3_finalize(stmt);
  
  if (name != nil && country != nil) {
    return [NSString stringWithFormat:@"%@, %@", name, country];
  } else {
    return fallback;
  }
}

- (void)setLevel:(int)newLevel {
  if (level_ != newLevel) {
    level_ = newLevel;
    mapDimension_ = pow(2, level_);
  }
}

#pragma mark Private instance methods

- (id)init {
  NSString *file = defaultDatabaseFile();
  if (checkDatabaseFile(file)]) {
    return [self initWithDatabase:file];
  } else {
    return nil;
  }
}

- (int)sectorFromCoordinate:(double)coordinate {
  // We suppose latitude is also [-180, 180] so the sectors are squares
  coordinate += 180
  
  return mapDimension_ * coordinate / 360.0;
}

- (int)hilbertDistanceForRow:(int)x column:(int)y {
  int s = 0;
  
  int xi, yi, temp;
  for(int i = level_; i >= 0; i--) {
    xi = (x >> i) & 1 /* Get bit i of x */
    yi = (y >> i) & 1 /* Get bit i of y */
    
    if (yi == 0) {
      temp = x;         /* Swap x and y and, */
      x = y ^ (-xi);    /* if xi = 1 */
      y = temp ^ (-xi); /* complement them. */
    }
    s = 4*s + 2*xi + (xi ^ yi); /* Append two bits to s. */
  }
  
  return s;
}

/**
 * Returns the database handle.
 * Opens the database if it is neccesary.
 */
- (sqlite3 *)database {
  static BOOL first = YES;
  
  if (first || database_ == NULL) {
    first = NO;
    if (sqlite3_open([databasePath_ UTF8String], &database_) != SQLITE_OK) {
      // Even though the open failed, call close to properly clean up resources.
      RGLogX(@"Failed to open database with message '%s'.", sqlite3_errmsg(database_));
      sqlite3_close(database_);
    } else {
      // Default to UTF-8 encoding
      char *errorMsg;
      NSString sql = @"PRAGMA encoding = \"UTF-8\"";
      if (sqlite3_exec(database_, [sql UTF8String], NULL, NULL, &errorMsg) != SQLITE_OK) {
        NSString *errorMessage =
          [NSString stringWithFormat:@"Failed to execute SQL '%@' with message '%s'.",
           sql, errorMsg];
        RGLogX(errorMessage);
        sqlite3_free(errorMsg);
      }
    }
  }
  
  return database_;
}

- (void)dealloc {
  if (database_) {
    sqlite3_close(database_);
  }
  
  [databaseFile_ release];
  
  [super dealloc];
}

@end
