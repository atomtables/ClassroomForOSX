//
//  GCAnnouncement.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GCCourse, GCUserProfile;

@interface GCAnnouncement : NSManagedObject

@property (nonatomic, retain) NSDate * updateTime;
@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) NSDate * scheduledTime;
@property (nonatomic, retain) id materials;
@property (nonatomic, retain) id individualStudentsOptions;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSDate * creationTime;
@property (nonatomic, retain) NSString * courseId;
@property (nonatomic, retain) NSString * assigneeMode;
@property (nonatomic, retain) NSString * alternateLink;
@property (nonatomic, retain) GCCourse *course;
@property (nonatomic, retain) GCUserProfile *creatorUser;

@end
