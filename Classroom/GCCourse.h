//
//  GCCourse.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GCUserProfile;

@interface GCCourse : NSManagedObject

@property (nonatomic, retain) NSString * alternateLink;
@property (nonatomic, retain) NSString * calendarId;
@property (nonatomic, retain) NSString * courseDescription;
@property (nonatomic, retain) NSString * courseDescriptionHeading;
@property (nonatomic, retain) NSString * courseGroupEmail;
@property (nonatomic, retain) NSString * courseState;
@property (nonatomic, retain) NSDate * creationTime;
@property (nonatomic, retain) NSString * enrollmentCode;
@property (nonatomic, retain) NSNumber * guardiansEnabled;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * room;
@property (nonatomic, retain) NSString * section;
@property (nonatomic, retain) NSString * subject;
@property (nonatomic, retain) NSString * teacherFolder;
@property (nonatomic, retain) NSString * teacherGroupEmail;
@property (nonatomic, retain) NSDate * updateTime;
@property (nonatomic, retain) NSNumber * userSelectedPosition;
@property (nonatomic, retain) NSOrderedSet *announcements;
@property (nonatomic, retain) NSSet *teacher;
@end

@interface GCCourse (CoreDataGeneratedAccessors)

- (void)insertObject:(NSManagedObject *)value inAnnouncementsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromAnnouncementsAtIndex:(NSUInteger)idx;
- (void)insertAnnouncements:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeAnnouncementsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInAnnouncementsAtIndex:(NSUInteger)idx withObject:(NSManagedObject *)value;
- (void)replaceAnnouncementsAtIndexes:(NSIndexSet *)indexes withAnnouncements:(NSArray *)values;
- (void)addAnnouncementsObject:(NSManagedObject *)value;
- (void)removeAnnouncementsObject:(NSManagedObject *)value;
- (void)addAnnouncements:(NSOrderedSet *)values;
- (void)removeAnnouncements:(NSOrderedSet *)values;
- (void)addTeacherObject:(GCUserProfile *)value;
- (void)removeTeacherObject:(GCUserProfile *)value;
- (void)addTeacher:(NSSet *)values;
- (void)removeTeacher:(NSSet *)values;

@end
