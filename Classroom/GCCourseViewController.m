//
//  GCCourseViewController.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 16/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCCourseViewController.h"
#import "GCDataManager.h"
#import "GCCourse.h"
#import "GCAnnouncement.h"
#import "GCAnnouncementInfoWindowController.h"

// claude magic???
static void* GCAnnouncementsContext = &GCAnnouncementsContext;

@interface GCCourseViewController ()

@property (strong, readwrite, nonatomic) NSArray* courseAnnouncements;

@end

@implementation GCCourseViewController {
    NSMutableArray* announcementWindowControllers;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        announcementWindowControllers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [self.announcementsTableView setTarget:self];
    [self.announcementsTableView setDoubleAction:@selector(announcementDoubleClicked:)];
}

NSString* announcements(NSString* item) {
    return [NSString stringWithFormat:@"announcements.%@", item];
}

- (void)dealloc {
    if (_course) [[GCDataManager shared] removeObserver:self forKeyPath:announcements(_course.id)];
}

// ran every time a new course is set
- (void)setCourse:(GCCourse *)course {
    if (_course) [[GCDataManager shared] removeObserver:self forKeyPath:announcements(_course.id)];
    
    _course = course;
    
    [[GCDataManager shared] addObserver:self forKeyPath:announcements(course.id) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:GCAnnouncementsContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == GCAnnouncementsContext) {
        id value = change[NSKeyValueChangeNewKey];
        self.courseAnnouncements = [value isKindOfClass:[NSArray class]] ? value : @[];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)announcementDoubleClicked:(id)sender {
    NSInteger row = [self.announcementsTableView clickedRow];
    NSArray* shown = [self.announcementsController arrangedObjects];
    GCAnnouncement* announcement = shown[row];
    
    // show ts window
    for (GCAnnouncementInfoWindowController* existing in announcementWindowControllers)
        if (existing.announcement == announcement) { [existing showWindow:self]; return; }
    
    // or just end it
    GCAnnouncementInfoWindowController* wc = [[GCAnnouncementInfoWindowController alloc] initWithAnnouncement:announcement];
    if (!announcementWindowControllers) announcementWindowControllers = [NSMutableArray array];
    [announcementWindowControllers addObject:wc];
    
    // dereference window rahhhhhh
    __block id token = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification object:wc.window queue:[NSOperationQueue mainQueue]usingBlock:^(NSNotification *note) {
        [[NSNotificationCenter defaultCenter] removeObserver:token];
        token = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [announcementWindowControllers removeObject:wc];
        });
    }];
    
    [wc showWindow:self];
}

@end
