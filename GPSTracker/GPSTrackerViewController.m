//
//  GPSTrackerViewController.m
//  GPSTracker
//
//  Created by tina on 6/8/13.
//  Copyright (c) 2013 tina. All rights reserved.
//

#import "GPSTrackerViewController.h"

#import <CoreLocation/CoreLocation.h>
#import <Dropbox/Dropbox.h>
#import <MapKit/MapKit.h>
#import "GPSTrackerLocationManager.h"

static NSString *sRegionIdentifierFormat = @"region:%d";
static NSString *gpsTableName = @"gps_locations";
static NSString *sDatastoreLocationLatitudeKey = @"latitude";
static NSString *sDatastoreLocationLongitudeKey = @"longitude";
static NSString *sDatastoreLocationTimestampKey = @"timestamp";
static NSString *sDatastoreLocationRadiusKey = @"radius";

static const double sRegionRadius = 1000;
static const double sHomeLatitude = 37.7863632;
static const double sHomeLongitude = -122.3938675;
static const CGFloat sLongLatDelta = 0.05;

@interface GPSTrackerViewController ()  <GPSTrackerLocationManagerDelegate>

@property (strong, readonly) DBAccountManager *accountManager;
@property (strong, readonly) DBAccount *account;
@property (strong, nonatomic) DBDatastore *store;
@property (strong, nonatomic) NSMutableDictionary *regionsDict;
@property (strong, nonatomic) NSMutableDictionary *lastRegionUpdateTimestampDict;
@property (strong, nonatomic) GPSTrackerLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIButton *linkButton;
@property (weak, nonatomic) IBOutlet UIButton *unlinkButton;

@end

@implementation GPSTrackerViewController

#pragma mark view methods

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	__weak GPSTrackerViewController *slf = self;
	[self.accountManager addObserver:self block:^(DBAccount *account) {
		[slf setupGPSLocations];
	}];
	
	[self setupGPSLocations];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    
	[self.accountManager removeObserver:self];
	if (_store) {
		[_store removeObserver:self];
	}
	self.store = nil;
}

- (void)dealloc {
	[_store removeObserver:self];
}

#pragma mark - IBActions

- (IBAction)didPressLink {
	[[DBAccountManager sharedManager] linkFromController:self];
}

- (IBAction)didPressUnlink {
	[[[DBAccountManager sharedManager] linkedAccount] unlink];
	self.store = nil;
    [self.regionsDict removeAllObjects];
    [self.lastRegionUpdateTimestampDict removeAllObjects];
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self validateButtons:NO];
}

#pragma mark - lazy instantiations

- (DBAccount *)account {
	return [DBAccountManager sharedManager].linkedAccount;
}

- (DBAccountManager *)accountManager {
	return [DBAccountManager sharedManager];
}

- (DBDatastore *)store {
	if (!_store) {
		_store = [DBDatastore openDefaultStoreForAccount:self.account error:nil];
	}
	return _store;
}

- (GPSTrackerLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [[GPSTrackerLocationManager alloc] init];
        _locationManager.delegate = self;
    }
    return _locationManager;
}

- (NSMutableDictionary *)regionsDict {
    if (!_regionsDict) {
        _regionsDict = [[NSMutableDictionary alloc] init];
    }
    return _regionsDict;
}

- (NSMutableDictionary *)lastRegionUpdateTimestampDict {
    if (!_lastRegionUpdateTimestampDict) {
        _lastRegionUpdateTimestampDict = [[NSMutableDictionary alloc] init];
    }
    return _lastRegionUpdateTimestampDict;
}

#pragma mark - private methods

- (void)populateRegions
{
    // start with a clean slate
    [self.regionsDict removeAllObjects];
    [self.lastRegionUpdateTimestampDict removeAllObjects];
    [self.mapView removeAnnotations:self.mapView.annotations];
    
    // query the datastore api, then do client side sorting based on timestamps
    NSArray *allRegions = [NSMutableArray arrayWithArray:[[self.store getTable:gpsTableName] query:nil error:nil]];
    allRegions = [allRegions sortedArrayUsingComparator: ^(DBRecord *obj1, DBRecord *obj2) {
		return [obj1[@"timestamp"] compare:obj2[@"timestamp"]];
	}];
    
    NSDate *prevTimestamp = nil;
    for (int i = 0; i < [allRegions count]; i++)
    {
        NSDictionary *locationDict = allRegions[i];
        CLLocationCoordinate2D location = {.latitude = [locationDict[sDatastoreLocationLatitudeKey] doubleValue], .longitude = [locationDict[sDatastoreLocationLongitudeKey] doubleValue]};

        // find the region from regionsDict. create a new one if needed
        CLRegion *region = [self mapCoordinate:location toRegions:[self.regionsDict allKeys]];
        
        // update lastRegionUpdateTimestampDict if needed
        NSDate *timestamp = locationDict[sDatastoreLocationTimestampKey];
        NSDate *oldTimeStamp = nil;
        CLRegion *aRegion = [self findRegion:region inRegions:[self.lastRegionUpdateTimestampDict allKeys]];
        if (aRegion) {
            oldTimeStamp = self.lastRegionUpdateTimestampDict[aRegion];
            [self.lastRegionUpdateTimestampDict removeObjectForKey:aRegion];
        }
        [self.lastRegionUpdateTimestampDict setObject:timestamp forKey:region];
        
        // update regionsDict if needed
        if (prevTimestamp) {
            NSTimeInterval timespan = [timestamp timeIntervalSinceDate:prevTimestamp];
            NSTimeInterval prevTimespan = 0;
            CLRegion *aRegion = [self findRegion:region inRegions:[self.regionsDict allKeys]];
            if (aRegion) {
                prevTimespan = [self.regionsDict[aRegion] doubleValue];
                [self.regionsDict removeObjectForKey:aRegion];
            }
            if (prevTimespan + timespan > 0) {
                [self.regionsDict setObject:[NSNumber numberWithDouble:prevTimespan + timespan] forKey:region];
            }
        }
        prevTimestamp = timestamp;
    }

    // compute percent for each pin
    double totalTime = 0;
    for (NSNumber *time in [self.regionsDict allValues])
    {
        totalTime += [time doubleValue];
    }
    // add processed points to map
    for (CLRegion *region in [self.regionsDict allKeys]) {
        MKPointAnnotation *point = [[MKPointAnnotation alloc] init];
        point.coordinate = region.center;
        point.title = [NSString stringWithFormat:@"%d%%", (int)floor([self.regionsDict[region] doubleValue] / totalTime * 100)];
        [self.mapView addAnnotation:point];
    }
    [self centerMapAroundHome];
}

- (void)validateButtons:(BOOL)isAccountLinked {
    self.unlinkButton.hidden = !isAccountLinked;
    self.linkButton.hidden = isAccountLinked;
    self.mapView.hidden = !isAccountLinked;
}

- (void)setupGPSLocations {
	if (self.account) {
		__weak GPSTrackerViewController *slf = self;
		[self.store addObserver:self block:^ {
			if (slf.store.status & (DBDatastoreIncoming | DBDatastoreOutgoing)) {
                [slf.store sync:nil];
				[slf populateRegions];
			}
		}];
        [self populateRegions];
        [self locationManager];
	} else {
		self.store = nil;
		self.regionsDict = nil;
        self.lastRegionUpdateTimestampDict = nil;
	}
    [self validateButtons:!!self.account];
}

- (CLRegion *)findRegion:(CLRegion *)region inRegions:(NSArray *)regions {
    for (CLRegion *aRegion in regions) {
        if ([aRegion containsCoordinate:region.center]) {
            return aRegion;
        }
    }
    return nil;
}

- (CLRegion *)mapCoordinate:(CLLocationCoordinate2D)coordinate toRegions:(NSArray *)regions {
    for (CLRegion *region in regions) {
        if ([region containsCoordinate:coordinate]) {
            return region;
        }
    }
    // create new region
    CLRegion *region = [[CLRegion alloc] initCircularRegionWithCenter:coordinate radius:sRegionRadius identifier:[NSString stringWithFormat:sRegionIdentifierFormat, [regions count]]];
    return region;
}

- (void)centerMapAroundHome {
    MKCoordinateSpan span = {.latitudeDelta = sLongLatDelta, .longitudeDelta = sLongLatDelta};
    CLLocationCoordinate2D location = {.latitude = sHomeLatitude, .longitude = sHomeLongitude};
    MKCoordinateRegion region; 
    region.span = span;
    region.center = location;
    [self.mapView setRegion:region animated:YES];
}

#pragma mark GPSTrackerLocationManagerDelegate methods
- (void)gpsTrackerLocationDidUpdate:(NSArray *)locations {
    DBTable *locationTbl = [self.store getTable:gpsTableName];
    for (CLLocation *location in locations) {
        CLRegion *region = [self mapCoordinate:location.coordinate toRegions:[self.regionsDict allKeys]];
        CLRegion *existingRegion = [self findRegion:region inRegions:[self.lastRegionUpdateTimestampDict allKeys]];
        NSDate *lastUpdateDate = nil;
        if (existingRegion) {
            lastUpdateDate = self.lastRegionUpdateTimestampDict[existingRegion];
        }
        if (region && lastUpdateDate && [location.timestamp timeIntervalSinceDate:lastUpdateDate] > 1) {
            [locationTbl insert:@{
                                    sDatastoreLocationLatitudeKey: @(region.center.latitude),
                                    sDatastoreLocationLongitudeKey: @(region.center.longitude),
                                    sDatastoreLocationRadiusKey: @(region.radius),
                                    sDatastoreLocationTimestampKey: location.timestamp
                                   }
            ];
        }
    }
}

@end
