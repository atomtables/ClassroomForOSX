//
//  GCCourseViewController.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 16/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCCourse.h"

@interface GCCourseViewController : NSViewController

@property (weak) IBOutlet NSTabView* tabView;
@property (weak) IBOutlet NSTableView* announcementsTableView;
@property (strong) IBOutlet NSArrayController *announcementsController;

@property (strong, nonatomic) GCCourse* course;
@property (strong, readonly) NSArray* courseAnnouncements;

@end
