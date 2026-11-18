//
//  GCUserProfile.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/11/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GCCourse;

@interface GCUserProfile : NSManagedObject

@property (nonatomic, retain) NSString * emailAddress;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSNumber * me;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * photoUrl;
@property (nonatomic, retain) NSSet *teachingCourses;
@end

@interface GCUserProfile (CoreDataGeneratedAccessors)

- (void)addTeachingCoursesObject:(GCCourse *)value;
- (void)removeTeachingCoursesObject:(GCCourse *)value;
- (void)addTeachingCourses:(NSSet *)values;
- (void)removeTeachingCourses:(NSSet *)values;

@end
