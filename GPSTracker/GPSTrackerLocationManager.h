//
//  GPSTrackerLocationManager.h
//  GPSTracker
//
//  Created by tina on 7/19/13.
//  Copyright (c) 2013 tina. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol GPSTrackerLocationManagerDelegate;

@interface GPSTrackerLocationManager : NSObject

@property (nonatomic, weak) id <GPSTrackerLocationManagerDelegate> delegate;

@end

@protocol GPSTrackerLocationManagerDelegate <NSObject>

- (void)gpsTrackerLocationDidUpdate:(NSArray *)locations;

@end