//
//  GCConstants.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 14/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - API Endpoints

#define kGCAPICoursesList @"https://classroom.googleapis.com/v1/courses"
#define kGCAPIProfileGet(userId) [NSString stringWithFormat:@"https://classroom.googleapis.com/v1/userProfiles/%@", userId];
#define kGCAPICourseTeachersList(courseId) [NSString stringWithFormat:@"https://classroom.googleapis.com/v1/courses/%@/teachers", courseId]
#define kGCAPICourseAnnouncementsList(courseId) [NSString stringWithFormat:@"https://classroom.googleapis.com/v1/courses/%@/announcements", courseId]

#pragma mark - NotificationCenter

#define kGCNCClassesUpdated @"dev.atomtables.Classroom.NotificationsWereUpdated"
#define kGCNCAnnouncementsUpdated @"dec.atomtables.Classroom.AnnouncementsWereUpdated"