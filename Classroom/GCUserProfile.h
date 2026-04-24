//
//  GCUserProfile.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 16/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GCCourse;

@interface GCUserProfile : NSManagedObject

@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * givenName;
@property (nonatomic, retain) NSString * familyName;
@property (nonatomic, retain) NSString * fullName;
@property (nonatomic, retain) NSString * emailAddress;
@property (nonatomic, retain) NSString * photoUrl;
@property (nonatomic, retain) NSString * verifiedTeacher;
@property (nonatomic, retain) NSString * me;
@property (nonatomic, retain) NSSet *ownedCourses;
@end

@interface GCUserProfile (CoreDataGeneratedAccessors)

- (void)addOwnedCoursesObject:(GCCourse *)value;
- (void)removeOwnedCoursesObject:(GCCourse *)value;
- (void)addOwnedCourses:(NSSet *)values;
- (void)removeOwnedCourses:(NSSet *)values;

@end
