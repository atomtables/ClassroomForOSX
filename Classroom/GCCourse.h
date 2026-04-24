//
//  GCCourse.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 16/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface GCCourse : NSManagedObject

@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * section;
@property (nonatomic, retain) NSString * courseDescriptionHeading;
@property (nonatomic, retain) NSString * courseDescription;
@property (nonatomic, retain) NSString * room;
@property (nonatomic, retain) NSDate * creationTime;
@property (nonatomic, retain) NSDate * updateTime;
@property (nonatomic, retain) NSString * enrollmentCode;
@property (nonatomic, retain) NSString * courseState;
@property (nonatomic, retain) NSString * alternateLink;
@property (nonatomic, retain) NSString * teacherGroupEmail;
@property (nonatomic, retain) NSString * courseGroupEmail;
@property (nonatomic, retain) NSString * teacherFolder;
@property (nonatomic, retain) NSNumber * guardiansEnabled;
@property (nonatomic, retain) NSString * calendarId;
@property (nonatomic, retain) NSString * subject;
@property (nonatomic, retain) NSManagedObject *owner;

@end
