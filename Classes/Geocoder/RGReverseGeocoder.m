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
    level_ = DEFAULT_DATABASE_LEVEL;
    
    if (!checkDatabaseFile(databaseFile_)) {
      RGLogX(@"Database schema version for '%@' database differs", databaseFile_);
      [databaseFile_ release];
      return nil;
    }
  }
  
  return self;
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
