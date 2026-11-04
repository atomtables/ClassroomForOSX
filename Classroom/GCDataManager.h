//
//  GCDataManager.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 24/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "Models.h"
#import <Foundation/Foundation.h>

// This is what the app interacts with to get data. This will cache course data,
// assignment data, etc. in storage so it can be interacted with offline, but will always
// attempt to get the latest data online with caching periods of maybe 30 seconds.
@interface GCDataManager : NSObject

@property (nonatomic, readonly) NSMutableDictionary* announcements;
@property (nonatomic, readonly) NSArray* courses;

+ (instancetype)shared;
- (id)init NS_UNAVAILABLE;
- (void)coursesWereUpdated;

@end
