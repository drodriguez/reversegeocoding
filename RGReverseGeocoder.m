//
//  RGReverseGeocoder.m
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

/*
 * Parts of this file are "inspired" in SQLitePersistentObjects
 * http://code.google.com/p/sqlitepersistentobjects/
 */

#import "RGReverseGeocoder.h"

#include <zlib.h>
#include <sys/mman.h>

#include "RGConfig.h"

#define MAX_DISTANCE_ON_EARTH 21000.0
#define EARTH_RADIUS 6378.0

#define RGLogX(s, ...) NSLog(@"%s - " s, __PRETTY_FUNCTION__, ##__VA_ARGS__)
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
@property (nonatomic, assign) int level;

/**
 * Init a RGReverseGeocoder with the default database.
 */
- (id)init;

/**
 * Check that the database file is current with the actual implementation.
 * This checks against the <databaseFile>.plist that the schema version is
 * supported.
 */
- (BOOL)checkDatabaseMetadata;

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
  
  NSString *defaultPath = [[paths objectAtIndex:0]
                           stringByAppendingPathComponent:DATABASE_FILENAME];
  
  return defaultPath;
}

/**
 * Check that the values on both the metadata files are the same.
 */
BOOL checkSameMetadataValues(NSString *file1, NSString *file2) {
  NSString *error;
  NSPropertyListFormat format;
  NSData *metadataData;
  NSDictionary *metadata;

  metadataData = [NSData dataWithContentsOfFile:file1];
  metadata = (NSDictionary *)[NSPropertyListSerialization
                              propertyListFromData:metadataData
                              mutabilityOption:NSPropertyListImmutable
                              format:&format
                              errorDescription:&error];
  if (!metadata) {
    RGLogX(@"Application database metadata failed to load with error '%@'.", error);
    return NO;
  }
  
  NSNumber *schemaVersion1 = [metadata objectForKey:@"schema_version"];
  NSString *databaseVersion1 = [metadata objectForKey:@"database_version"];
  NSNumber *databaseLevel1 = [metadata objectForKey:@"database_level"];

  metadataData = [NSData dataWithContentsOfFile:file2];
  metadata = (NSDictionary *)[NSPropertyListSerialization
                              propertyListFromData:metadataData
                              mutabilityOption:NSPropertyListImmutable
                              format:&format
                              errorDescription:&error];
  if (!metadata) {
    RGLogX(@"Application support database metadata failed to load with error '%@'.", error);
    return NO;
  }
  
  NSNumber *schemaVersion2 = [metadata objectForKey:@"schema_version"];
  NSString *databaseVersion2 = [metadata objectForKey:@"database_version"];
  NSNumber *databaseLevel2 = [metadata objectForKey:@"database_level"];
  
  return [schemaVersion1 isEqualToNumber:schemaVersion2] &&
    [databaseLevel1 isEqualToNumber:databaseLevel2] &&
    [databaseVersion1 isEqualToString:databaseVersion2];
}

/**
 * Decompress a gzip compressed file into the destination file.
 */
BOOL decompressFile(NSString *origFile, NSString *destFile) {
  BOOL done = NO;
  char *buffer;
  int bufferSize;
  
  gzFile inFile = gzopen([origFile UTF8String], "rb");
  if (!inFile) {
    RGLog(@"Can not read origin database");
    return NO;
  }
  
  int outFile = open([destFile UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
  if (outFile == -1) {
    RGLog(@"Can not create destination database (%d)", errno);
    gzclose(inFile);
    return NO;
  }
  
  
  buffer = mmap(NULL, 256*1024, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
  bufferSize = 256*1024;
  if (buffer == (char *)(-1)) {
    buffer = malloc(16*1024);
    bufferSize = 16*1024;
  }
  
  while(1) {
    int readLen = gzread(inFile, buffer, bufferSize);
    
    if (!readLen) { /* end of file */
      done = YES;
      break;
    }
    
    if (readLen < 0) { /* error */
      RGLog("Read error decompressing data");
      break;
    }
    
    if (outFile >= 0) {
      int writeLen;
      do {
        writeLen = write(outFile, buffer, readLen);
      } while (writeLen < 0 && errno == EINTR);
      if (writeLen < readLen) {
        RGLog("Write error decompressing data");
        break;
      }
    }
  }
  
  if (bufferSize == 16*1024) {
    free(buffer);
  } else {
    munmap(buffer, bufferSize);
  }
  
  gzclose(inFile);
  close(outFile);
  
  return done;
}

/**
 * Returns the spherical distance between two points.
 */
double sphericalDistance(double lat1, double lon1, double lat2, double lon2) {
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
  
  return EARTH_RADIUS*(acos(clat1*clon1*clat2*clon2 +
                       clat1*slon1*clat2*slon2 +
                       slat1*slat2));
}

@implementation RGReverseGeocoder

@synthesize database = database_;
@synthesize level = level_;

#pragma mark Class methods
+ (id)sharedGeocoder {
  @synchronized(self) {
    if (sharedInstance == nil) {
      sharedInstance = [[self alloc] init];
    }
  }
  
  return sharedInstance;
}

+ (BOOL)setupDatabase {
  NSString *appResourcesPath = [[NSBundle mainBundle] resourcePath];
  NSString *dbPath = [appResourcesPath stringByAppendingPathComponent:DATABASE_FILENAME @".gz"];
  NSString *plistPath = [appResourcesPath stringByAppendingPathComponent:DATABASE_FILENAME @".plist"];
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if (![fileManager isReadableFileAtPath:dbPath] ||
      ![fileManager isReadableFileAtPath:plistPath]) {
    RGLog(@"Compressed database or metadata are not readable from application bundle");
    return NO;
  }
  
  NSString *dbDestPath = defaultDatabaseFile();
  if (!dbDestPath) {
    RGLog(@"Can not find application support directory");
    return NO;
  }
  NSString *plistDestPath = [dbDestPath stringByAppendingString:@".plist"];
  
  if (![fileManager fileExistsAtPath:dbDestPath] ||
      ![fileManager fileExistsAtPath:plistDestPath] ||
      !checkSameMetadataValues(plistPath, plistDestPath)) {
    NSError *error;
    // Create Application Support directory if needed
    NSString *appSupportDir = [dbDestPath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:appSupportDir]) {
      if ([fileManager createDirectoryAtPath:appSupportDir
                 withIntermediateDirectories:YES
                                  attributes:nil
                                       error:&error]) {
        RGLog(@"Can not create Application Support directory with error (%d) '%@'",
              [error code], [error description]);
        return NO;
      }
    }
    
    if([fileManager fileExistsAtPath:plistDestPath]) {
      if (![fileManager removeItemAtPath:plistDestPath error:&error]) {
        RGLog(@"'%@' already exist and can not be removed with error (%d) '%@'",
              plistDestPath, [error code], [error description]);
        return NO;
      }
    }
    
    if (![fileManager copyItemAtPath:plistPath toPath:plistDestPath error:&error]) {
      RGLog(@"Can not copy metadata file with error (%d) '%@'",
            [error code], [error description]);
      return NO;
    }
    
    if (!decompressFile(dbPath, dbDestPath)) {
      RGLog(@"Can not decompress database file");
      return NO;
    }
  }
  
  /* The destination files exist and they seem to be up-to-date versions, or
   we have copied the files succesfully */
  return YES;
}

#pragma mark Public instance methods

- (id)initWithDatabase:(NSString *)databasePath {
  if (self = [super init]) {
    databasePath_ = [databasePath copy];
    
    if (![self checkDatabaseMetadata]) {
      RGLogX(@"Database schema version for '%@' database differs", databasePath_);
      [databasePath_ release];
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
  
  // Get the eight sectors around the central one
  NSMutableArray *sectors = [[[NSMutableArray alloc] init] autorelease];
  int sector;
  for (int i = -1; i <= 1; i++) {
    for (int j = -1; j <= 1; j++) {
      if (row+i < 0 || row+i >= mapDimension_ || col+j < 0 || col+j >= mapDimension_) {
        continue;
      }
      sector = [self hilbertDistanceForRow:row+i column:col+j];
      [sectors addObject:[NSNumber numberWithInt:sector]];
    }
  }
  
  NSMutableString *query = [[[NSMutableString alloc] init] autorelease];
  [query appendString:@"SELECT cities.name, countries.name, latitude, longitude "
    "FROM cities JOIN countries ON cities.country_id = countries.id "
    "WHERE sector IN ("];
  BOOL first = YES;
  for(NSNumber *s in sectors) {
    [query appendFormat:@"%@%d", (first ? @"" : @", "), [s intValue]];
    first = NO;
  }
  [query appendString:@")"];
  
  sqlite3 *db = self.database;
  sqlite3_stmt *stmt;
  if (sqlite3_prepare_v2(db, [query UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
    RGLog(@"Can not prepare SQlite statement with error '%s'.", sqlite3_errmsg(db));
    return fallback;
  }
  
  NSString *name = nil, *country = nil;
  double minDistance = MAX_DISTANCE_ON_EARTH;
#if defined(DEBUG)
  double maxDistance = 0.0;
#endif
  while (sqlite3_step(stmt) == SQLITE_ROW) {
    double lat = sqlite3_column_double(stmt, 2);
    double lon = sqlite3_column_double(stmt, 3);
    double distance = sphericalDistance(location.coordinate.latitude,
                                        location.coordinate.longitude,
                                        lat,
                                        lon);
    if (distance < minDistance) {
      minDistance = distance;
      
      const char *text = (const char *)sqlite3_column_text(stmt, 0);
      if (text == nil) {
        RGLog(@"Row without name!?");
        sqlite3_finalize(stmt);
        if (country) [country release];
        return fallback;
      }
      name = [NSString stringWithUTF8String:text];
      
      text = (const char *)sqlite3_column_text(stmt, 1);
      if (text == nil) {
        RGLog(@"Row without country!?");
        sqlite3_finalize(stmt);
        if (name) [name release];
        return fallback;
      }
      country = [NSString stringWithUTF8String:text];
    }
#if defined(DEBUG)
    if (distance > maxDistance) {
      maxDistance = distance;
    }
#endif
  }
  sqlite3_finalize(stmt);
  
  RGLog(@"Minimun distance: %f", minDistance);
#if defined(DEBUG)
  RGLog(@"Maximun distance: %f", maxDistance);
#endif
  
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
  return [self initWithDatabase:defaultDatabaseFile()];
}

- (BOOL)checkDatabaseMetadata {
  NSString *plistFile = [databasePath_ stringByAppendingString:@".plist"];
  
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
  if ([databaseSchemaVersion intValue] != SCHEMA_VERSION) {
    return NO;
  }
  
  schemaVersion_ = [databaseSchemaVersion intValue];
  databaseVersion_ = [[metadata objectForKey:@"database_version"] retain];
  self.level = [[metadata objectForKey:@"database_level"] intValue];
  
  return YES;
}  

- (int)sectorFromCoordinate:(double)coordinate {
  // We suppose latitude is also [-180, 180] so the sectors are squares
  coordinate += 180;
  
  return mapDimension_ * coordinate / 360.0;
}

- (int)hilbertDistanceForRow:(int)x column:(int)y {
  int s = 0;
  
  int xi, yi, temp;
  for(int i = level_; i >= 0; i--) {
    xi = (x >> i) & 1; /* Get bit i of x */
    yi = (y >> i) & 1; /* Get bit i of y */
    
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
      NSString *sql = @"PRAGMA encoding = \"UTF-8\"";
      if (sqlite3_exec(database_, [sql UTF8String], NULL, NULL, &errorMsg) != SQLITE_OK) {
        RGLogX(@"Failed to execute SQL '%@' with message '%s'.", sql, errorMsg);
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
  
  [databasePath_ release];
  
  [super dealloc];
}

@end
