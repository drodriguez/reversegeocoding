//
//  ReverseGeocodingAppDelegate.m
//  ReverseGeocoding
//
//  Created by Daniel Rodríguez Troitiño on 27/03/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import "ReverseGeocodingAppDelegate.h"

@implementation ReverseGeocodingAppDelegate

@synthesize window;


- (void)applicationDidFinishLaunching:(UIApplication *)application {
  locationManager = [[CLLocationManager alloc] init];
  locationManager.delegate = self;
  
  if ([RGReverseGeocoder setupDatabase]) {
    reverseGeocoder = [RGReverseGeocoder sharedGeocoder];
  }
  
  [locationManager startUpdatingLocation];
  
  [window makeKeyAndVisible];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
  NSMutableString *update = [[[NSMutableString alloc] init] autorelease];
  
  // Timestamp
  NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
  [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
  [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
  [update appendFormat:@"%@\n\n", [dateFormatter stringFromDate:newLocation.timestamp]];
  
  // Horizontal coordinates
  if (signbit(newLocation.horizontalAccuracy)) {
    // Negative accuracy means an invalid or unavailable measurement
    [update appendString:@"Latitude & Longitude unavailable\n"];
  } else {
    // CoreLocation returns positive for North & East, negative for South & West
    [update appendFormat:@"%@ %f - %@ %f\n",
     (signbit(newLocation.coordinate.latitude) ? @"S" : @"N"),
     newLocation.coordinate.latitude,
     (signbit(newLocation.coordinate.longitude) ? @"W" : @"E"),
     newLocation.coordinate.longitude];
    [update appendFormat:@"Horizontal accuracy: %f\n", newLocation.horizontalAccuracy];
  }
  
  if (signbit(newLocation.verticalAccuracy)) {
    // Negative accuracy means an invalid or unavailable measurement
    [update appendString:@"Altitude unavailable\n"];
  } else {
    // Positive and negative in altitude denore above & below the sea level, respectively
    [update appendFormat:@"Altitude: %f %@\n", fabs(newLocation.altitude),
     (signbit(newLocation.altitude) ? @"below sea level" : @"above sea level")];
    [update appendFormat:@"Vertical accuracy: %f\n", newLocation.verticalAccuracy];
  }
  
  if (reverseGeocoder != nil) {
    [update appendString:[reverseGeocoder placeForLocation:newLocation]];
  }
  
  locationInfo.text = update;
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
  // TODO: do something here
}

- (void)dealloc {
  [locationManager release];
  [reverseGeocoder release];
  [window release];
  [super dealloc];
}


@end
