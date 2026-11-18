//
//  GCDataFetcher.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "Models.h"
#import <Foundation/Foundation.h>

@interface GCDataFetcher : NSObject

+ (instancetype)main;
- (BOOL)retrieveRequiredValuesFromScrapedGoogleClassroomPage;

#pragma mark - requires scope classroom.courses.readonly
// https://classroom.googleapis.com/v1/courses/{idStr}
- (OSStatus)getCourseWithId:(NSString*)idStr withCompletionHandler:(void (^)(GCCourse* course, NSError*))comp;
// https://classroom.googleapis.com/v1/courses
- (BOOL)listCourses:(void (^)(NSArray* courses, NSError*))comp;
- (BOOL)listTeachersInCourse:(NSString*)courseId completion:(void (^)(NSArray* teachers, NSError*))comp;
- (BOOL)listAllAnnouncementsInCourse:(NSString *)courseId completion:(void (^)(NSArray *, NSError *))comp;
- (BOOL)getUserProfile:(NSString*)userId completion:(void (^)(NSArray* profileData, NSError*))comp;
- (BOOL)getUserProfiles:(NSArray*)userIds completion:(void (^)(NSArray* profileData, NSError*))comp;
// - (OSStatus)getCourseGradingPeriodSettingsWithId:(NSString*)idStr withCompletionHandler:(void (^)(NSError*, NSURLResponse*))comp;

#pragma mark - requires scope classroom.courses
- (OSStatus)createCourseWithProperties:(GCCourse*)dict withCompletionHandler:(void (^)(GCCourse* course, NSError*, NSURLResponse*))comp;
- (OSStatus)deleteCourseWithProperties:(GCCourse*)dict withCompletionHandler:(void (^)(NSError*, NSURLResponse*))comp;
- (OSStatus)updateCourseWithId:(NSString*)idStr withMask:(NSArray*)mask andCourseData:(GCCourse*)course withCompletionHandler:(void (^)(GCCourse*, NSError*, NSURLResponse*))comp;
- (OSStatus)updateCourseWithId:(NSString*)idStr withNewCourse:(GCCourse*)course withCompletionHandler:(void (^)(GCCourse*, NSError*, NSURLResponse*))comp;
// - (OSStatus)updateCourseGradingPeriodSettingsWithId:(NSString*)idStr withCompletionHandler:(void (^)(NSError*, NSURLResponse*))comp;

@end
