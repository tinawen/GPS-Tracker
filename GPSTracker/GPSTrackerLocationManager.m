//
//  GPSTrackerLocationManager.m
//  GPSTracker
//
//  Created by tina on 7/19/13.
//  Copyright (c) 2013 tina. All rights reserved.
//

#import "GPSTrackerLocationManager.h"

#import <CoreLocation/CoreLocation.h>

@interface GPSTrackerLocationManager() <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;

@end

@implementation GPSTrackerLocationManager

- (id)init {
    if ((self = [super init])) {
        [self.locationManager startMonitoringSignificantLocationChanges];
    }
    return self;
}

- (void)dealloc {
    [self.locationManager stopMonitoringSignificantLocationChanges];
}

- (CLLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        [_locationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
    }
    return _locationManager;
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [self.delegate gpsTrackerLocationDidUpdate:locations];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (error.code == kCLErrorDenied) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"GPS Tracker can't work!", @"Error info") message:NSLocalizedString(@"You denied location update to GPSTracker", @"More error info") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"Confirmation button title") otherButtonTitles:nil] show];
    }
}

@end
