//
//  ReverseGeocodingAppDelegate.h
//  ReverseGeocoding
//
//  Created by Daniel Rodríguez Troitiño on 27/03/09.
//  Copyright Daniel Rodríguez Troitiño 2009. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "RGReverseGeocoder.h"

@interface ReverseGeocodingAppDelegate : NSObject <UIApplicationDelegate, CLLocationManagerDelegate> {
  UIWindow *window;
  IBOutlet UITextView *locationInfo;
  CLLocationManager *locationManager;
  RGReverseGeocoder *reverseGeocoder;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@end

