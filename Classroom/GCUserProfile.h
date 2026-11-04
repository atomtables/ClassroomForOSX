//
//  GCUserProfile.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GCCourse;

@interface GCUserProfile : NSManagedObject

@property (nonatomic, retain) NSString * emailAddress;
@property (nonatomic, retain) NSString * familyName;
@property (nonatomic, retain) NSString * fullName;
@property (nonatomic, retain) NSString * givenName;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * me;
@property (nonatomic, retain) NSString * photoUrl;
@property (nonatomic, retain) NSNumber * verifiedTeacher;
@property (nonatomic, retain) NSSet *teachingCourses;
@end

@interface GCUserProfile (CoreDataGeneratedAccessors)

- (void)addTeachingCoursesObject:(GCCourse *)value;
- (void)removeTeachingCoursesObject:(GCCourse *)value;
- (void)addTeachingCourses:(NSSet *)values;
- (void)removeTeachingCourses:(NSSet *)values;

@end
