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

    // Override point for customization after application launch
    [window makeKeyAndVisible];
}


- (void)dealloc {
    [window release];
    [super dealloc];
}


@end
