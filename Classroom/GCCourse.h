//
//  GCCourse.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/11/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GCMaterial, GCUserProfile;

@interface GCCourse : NSManagedObject

@property (nonatomic, retain) NSString * alternateLink;
@property (nonatomic, retain) NSString * banner;
@property (nonatomic, retain) NSString * calendarId;
@property (nonatomic, retain) NSNumber * classRole;
@property (nonatomic, retain) NSString * colorBackground;
@property (nonatomic, retain) NSString * colorFavicon;
@property (nonatomic, retain) NSString * colorForeground;
@property (nonatomic, retain) NSString * colorPrimary;
@property (nonatomic, retain) NSNumber * colorShouldAdjustContrast;
@property (nonatomic, retain) NSString * courseDescription;
@property (nonatomic, retain) NSString * courseDescriptionHeading;
@property (nonatomic, retain) NSString * courseGroupEmail;
@property (nonatomic, retain) NSNumber * courseState;
@property (nonatomic, retain) NSDate * creationTime;
@property (nonatomic, retain) NSString * enrollmentCode;
@property (nonatomic, retain) NSNumber * guardiansEnabled;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * levels;
@property (nonatomic, retain) NSString * meetLink;
@property (nonatomic, retain) NSNumber * meetRole;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * orderToken;
@property (nonatomic, retain) NSNumber * orderTokenSortable;
@property (nonatomic, retain) NSString * room;
@property (nonatomic, retain) NSString * section;
@property (nonatomic, retain) NSString * subject;
@property (nonatomic, retain) NSString * teacherFolder;
@property (nonatomic, retain) NSString * teacherGroupEmail;
@property (nonatomic, retain) NSDate * updateTime;
@property (nonatomic, retain) NSNumber * userSelectedPosition;
@property (nonatomic, retain) NSOrderedSet *announcements;
@property (nonatomic, retain) NSSet *students;
@property (nonatomic, retain) NSSet *teacher;
@property (nonatomic, retain) GCMaterial *materials;
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
- (void)addStudentsObject:(GCUserProfile *)value;
- (void)removeStudentsObject:(GCUserProfile *)value;
- (void)addStudents:(NSSet *)values;
- (void)removeStudents:(NSSet *)values;

- (void)addTeacherObject:(GCUserProfile *)value;
- (void)removeTeacherObject:(GCUserProfile *)value;
- (void)addTeacher:(NSSet *)values;
- (void)removeTeacher:(NSSet *)values;

@end
