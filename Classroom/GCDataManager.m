//
//  GCDataManager.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 24/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCLoginManager.h"
#import "GCDataManager.h"
#import "GCCourse.h"
#import "GCAppDelegate.h"
#import "GCDataFetcher.h"
#import "GCAnnouncement.h"

int MAX_CACHING_PERIOD = 30;

NSString* GCAddHttpProtocolIfMissingToURLString(NSString* string) {
    NSString* urlString;
    if ([string hasPrefix:@"//"]) urlString = [NSString stringWithFormat:@"https:%@", string];
    else urlString = string ?: @"http://255.255.255.0:5555";
    return urlString;
}

static id GCNonNull(id v) { return (v == [NSNull null]) ? nil : v; }
static NSDate *GCDateFromAPIString(NSString *s) {
    if (![s isKindOfClass:[NSString class]]) return nil;
    static NSDateFormatter *withMs, *withoutMs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLocale *posix = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        NSTimeZone *utc = [NSTimeZone timeZoneForSecondsFromGMT:0];
        withMs = [[NSDateFormatter alloc] init];
        withMs.locale = posix; withMs.timeZone = utc;
        withMs.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        withoutMs = [[NSDateFormatter alloc] init];
        withoutMs.locale = posix; withoutMs.timeZone = utc;
        withoutMs.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    });
    return [withMs dateFromString:s] ?: [withoutMs dateFromString:s];
}

@interface GCDataManager ()
@property (nonatomic, readwrite) NSMutableDictionary* announcements;
@property (nonatomic, readwrite) NSArray* courses;
@end

@implementation GCDataManager {
    NSTimer* classUpdateTimer;
    NSArray* _courses;
    dispatch_queue_t networkQueue;
    
    NSMutableSet* teachersBeingLoaded;
    void(^teachersLoadedCompletion)(NSError*);
    
    NSMutableSet* announcementsInFlight;
}

+ (instancetype)shared {
    static GCDataManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    self = [super init];
    
    self.announcements = [[NSMutableDictionary alloc] init];
    networkQueue = dispatch_queue_create("dev.atomtables.Classroom.network-queue", DISPATCH_QUEUE_CONCURRENT);
    teachersBeingLoaded = [[NSMutableSet alloc] init];
    announcementsInFlight = [[NSMutableSet alloc] init];
    classUpdateTimer = [NSTimer timerWithTimeInterval:30*60 target:self selector:@selector(updateCourses) userInfo:nil repeats:true];
    [classUpdateTimer fire];
    [[NSRunLoop mainRunLoop] addTimer:classUpdateTimer forMode:NSDefaultRunLoopMode];
    
    [[GCLoginManager main] addObserver:self
                            forKeyPath:@"isAuthenticated"
                               options:NSKeyValueObservingOptionNew
                               context:nil];
    
    return self;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options context:(void *)context {
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
    
    static NSString *const prefix = @"announcements.";
    if ([keyPath hasPrefix:prefix]) {
        NSString *courseId = [keyPath substringFromIndex:prefix.length];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateAnnouncementsForCourseId:courseId];
        });
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([object isKindOfClass:[GCLoginManager class]]) {
        if ([keyPath isEqualToString:@"isAuthenticated"]) {
            if ([change[NSKeyValueChangeNewKey] boolValue] == true) {
                [self updateCourses];
            } else {
                _courses = nil;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)dealloc {
    [classUpdateTimer invalidate];
}

- (NSArray *)fetchCoursesWithPredicate:(NSPredicate *)predicate sortDescriptors:(NSArray *)sorts {
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"GCCourse"];
    req.predicate = predicate;
    req.sortDescriptors = sorts;
    req.relationshipKeyPathsForPrefetching = @[@"teacher"];
    NSError *err = nil;
    NSArray *result = [[[NSApp delegate] managedObjectContext] executeFetchRequest:req error:&err];
    if (err) NSLog(@"fetch failed: %@", err);
    return result ?: @[];
}

- (NSArray*)courses {
    return _courses;
}

- (NSArray*)announcementsForCourseId:(NSString*)courseId {
    NSArray* cached = self.announcements[courseId];
    if (!cached) [self updateAnnouncementsForCourseId:courseId];   // the first read starts the load
    return cached ?: @[];
}

#pragma mark - Course Cache Update Selectors

- (GCUserProfile*)getTeacherWithId:(NSString*)userId context:(NSManagedObjectContext*)context courseId:(NSString*)courseId {
    if (!userId || userId.length == 0) return nil;
    
    NSFetchRequest* fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"GCUserProfile"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"id == %@", userId];
    fetchRequest.fetchLimit = 1;
    
    NSError* error = nil;
    GCUserProfile* profile = [[context executeFetchRequest:fetchRequest error:&error] firstObject];
    
    if (!profile) {
        profile = [NSEntityDescription insertNewObjectForEntityForName:@"GCUserProfile"
                                                inManagedObjectContext:context];
        profile.id = userId;
        
        [teachersBeingLoaded addObject:userId];
        dispatch_async(networkQueue, ^{
            [GCDataFetcher getUserProfile:userId completion:^(NSDictionary* item, NSError* error) {
                if (error) {
                    NSLog(@"Error loading user profile %@: %@", userId, error);
                }
                
                NSManagedObjectContext* context = [(GCAppDelegate*)[NSApp delegate] managedObjectContext];
                
                NSDictionary* courseDict = item;
                profile.givenName = GCNonNull(courseDict[@"name"][@"givenName"]);
                profile.familyName = GCNonNull(courseDict[@"name"][@"familyName"]);
                profile.fullName = GCNonNull(courseDict[@"name"][@"fullName"]);
                profile.emailAddress = GCNonNull(courseDict[@"emailAddress"]);
                profile.photoUrl = GCAddHttpProtocolIfMissingToURLString(GCNonNull(courseDict[@"photoUrl"]));
                profile.verifiedTeacher = GCNonNull(courseDict[@"verifiedTeacher"]);
                
                NSError *saveError = nil;
                if ([context hasChanges]) {
                    [context save:&saveError];
                }
                
                [teachersBeingLoaded removeObject:userId];
                if ([teachersBeingLoaded count] == 0 && teachersLoadedCompletion) {
                    NSLog(@"teachersLoadedCompletion ran");
                    teachersLoadedCompletion(nil);
                }
            }];
        });
    }
    return profile;
}

- (GCCourse*)courseWithId:(NSString *)courseId context:(NSManagedObjectContext *)context {
    NSFetchRequest* req = [NSFetchRequest fetchRequestWithEntityName:@"GCCourse"];
    req.predicate = [NSPredicate predicateWithFormat:@"id == %@", courseId];
    req.fetchLimit = 1;
    GCCourse* c = [[context executeFetchRequest:req error:NULL] firstObject];
    if (!c) {
        GCCourse* newCourse = [NSEntityDescription insertNewObjectForEntityForName:@"GCCourse" inManagedObjectContext:context];
        newCourse.id = courseId;
        return newCourse;
    }
    return c;
}

- (GCAnnouncement*)announcementWithId:(NSString*)announcementId context:(NSManagedObjectContext*)context {
    NSFetchRequest* req = [NSFetchRequest fetchRequestWithEntityName:@"GCAnnouncement"];
    req.predicate = [NSPredicate predicateWithFormat:@"id == %@", announcementId];
    req.fetchLimit = 1;
    GCAnnouncement* a = [[context executeFetchRequest:req error:NULL] firstObject];
    if (!a) {
        a = [NSEntityDescription insertNewObjectForEntityForName:@"GCAnnouncement" inManagedObjectContext:context];
        a.id = announcementId;
    }
    return a;
}

- (void)updateCourses {
    [self coursesWereUpdated];
    
    if (![[GCLoginManager main] accessCode].length) return;
    [GCDataFetcher listCourses:^(NSArray* courses, NSError* err) {
        NSMutableArray* arr = [[NSMutableArray alloc] init];
        NSManagedObjectContext* context = [(GCAppDelegate*)[NSApp delegate] managedObjectContext];
        NSDateFormatter* form = [[NSDateFormatter alloc] init];
        [form setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssX"];
        [form setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        
        for (NSDictionary *courseDict in courses) {
            GCCourse* course = [self courseWithId:courseDict[@"id"] context:context];
            
            course.id = GCNonNull(courseDict[@"id"]);
            course.name = GCNonNull(courseDict[@"name"]);
            course.section = GCNonNull(courseDict[@"section"]);
            course.courseDescriptionHeading = GCNonNull(courseDict[@"descriptionHeading"]);
            course.courseDescription = GCNonNull(courseDict[@"description"]);
            course.room = GCNonNull(courseDict[@"room"]);
            course.enrollmentCode = GCNonNull(courseDict[@"enrollmentCode"]);
            course.courseState = GCNonNull(courseDict[@"courseState"]);
            course.alternateLink = GCNonNull(courseDict[@"alternateLink"]);
            course.teacherGroupEmail = GCNonNull(courseDict[@"teacherGroupEmail"]);
            course.courseGroupEmail = GCNonNull(courseDict[@"courseGroupEmail"]);
            course.guardiansEnabled = GCNonNull(courseDict[@"guardiansEnabled"]);
            course.calendarId = GCNonNull(courseDict[@"calendarId"]);
            course.subject = GCNonNull(courseDict[@"subject"]);
            [course addTeacherObject:[self getTeacherWithId:courseDict[@"ownerId"] context:context courseId:course.id]];
            course.creationTime = GCDateFromAPIString(GCNonNull(courseDict[@"creationTime"]));
            course.updateTime = GCDateFromAPIString(GCNonNull(courseDict[@"updateTime"]));
            
            id teacherFolderObj = courseDict[@"teacherFolder"];
            if ([teacherFolderObj isKindOfClass:[NSDictionary class]]) {
                course.teacherFolder = teacherFolderObj[@"id"];
            } else if ([teacherFolderObj isKindOfClass:[NSString class]]) {
                course.teacherFolder = teacherFolderObj;
            }
            
            [arr addObject:course];
        }
        
        NSSet* returnedIds = [NSSet setWithArray:[courses valueForKey:@"id"]];
        NSFetchRequest* stale = [NSFetchRequest fetchRequestWithEntityName:@"GCCourse"];
        stale.predicate = [NSPredicate predicateWithFormat:@"NOT (id IN %@)", returnedIds];
        for (GCCourse* old in [context executeFetchRequest:stale error:NULL]) {
            [context deleteObject:old];
        }
        
        NSError *saveError = nil;
        if ([context hasChanges]) {
            [context save:&saveError];
        }
        
        // stupid ahh code wwon't allow this to be weak...
        GCDataManager* __unsafe_unretained weakSelf = self;
        teachersLoadedCompletion = ^(NSError* error) {
            NSLog(@"loading teachersLoadedCompletion");
            if (error) {
                NSLog(@"an error occurred to teachersLoadedCompletion: %@", error);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.courses = arr; // Triggers KVO
                [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCClassesUpdated object:nil];
            });
            weakSelf->teachersLoadedCompletion = nil;
        };
        if ([teachersBeingLoaded count] == 0) teachersLoadedCompletion(saveError);
    }];
}
- (void)updateAnnouncementsForCourseId:(NSString*)courseId {
    if (courseId.length == 0) return;
    
    [self announcementsWereUpdatedForCourse:courseId];
    
    if ([announcementsInFlight containsObject:courseId]) return;
    [announcementsInFlight addObject:courseId];
    
    [GCDataFetcher listAnnouncementsInCourse:courseId completion:^(NSArray* items, NSError* err) {
        [announcementsInFlight removeObject:courseId];
        if (err) {
            NSLog(@"announcement refresh failed for %@: %@", courseId, err);
            return;
        }
        
        NSManagedObjectContext* context = [(GCAppDelegate*)[NSApp delegate] managedObjectContext];
        NSFetchRequest* cr = [NSFetchRequest fetchRequestWithEntityName:@"GCCourse"];
        cr.predicate = [NSPredicate predicateWithFormat:@"id == %@", courseId];
        cr.fetchLimit = 1;
        GCCourse* course = [[context executeFetchRequest:cr error:NULL] firstObject];
        if (!course) return;
        
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:items.count];
        for (NSDictionary* d in items) {
            GCAnnouncement* a = [self announcementWithId:d[@"id"] context:context];
            a.courseId = courseId;
            a.course = course;
            a.text = GCNonNull(d[@"text"]);
            a.state = GCNonNull(d[@"state"]);
            a.alternateLink = GCNonNull(d[@"alternateLink"]);
            a.assigneeMode = GCNonNull(d[@"assigneeMode"]);
            a.materials = GCNonNull(d[@"materials"]);
            a.individualStudentsOptions = GCNonNull(d[@"individualStudentsOptions"]);
            a.creationTime = GCDateFromAPIString(GCNonNull(d[@"creationTime"]));
            a.updateTime = GCDateFromAPIString(GCNonNull(d[@"updateTime"]));
            a.scheduledTime = GCDateFromAPIString(GCNonNull(d[@"scheduledTime"]));
            a.creatorUser = [self getTeacherWithId:GCNonNull(d[@"creatorUserId"]) context:context courseId:courseId];
            [arr addObject:a];
        }
        NSSet* returnedIds = [NSSet setWithArray:[items valueForKey:@"id"]];
        NSFetchRequest* stale = [NSFetchRequest fetchRequestWithEntityName:@"GCAnnouncement"];
        stale.predicate = [NSPredicate predicateWithFormat:@"courseId == %@ AND NOT (id IN %@)", courseId, returnedIds];
        for (GCAnnouncement* old in [context executeFetchRequest:stale error:NULL]) {
            [context deleteObject:old];
        }
        
        NSError* saveError = nil;
        if ([context hasChanges] && ![context save:&saveError]) NSLog(@"saving announcements failed: %@", saveError);
        
        GCDataManager* __unsafe_unretained weakSelf = self;
        teachersLoadedCompletion = ^(NSError* error) {
            NSLog(@"loading teachersLoadedCompletion");
            if (error) {
                NSLog(@"an error occurred to teachersLoadedCompletion: %@", error);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.announcements willChangeValueForKey:courseId];
                weakSelf.announcements[courseId] = arr; // Triggers KVO
                [weakSelf.announcements didChangeValueForKey:courseId];
                [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCAnnouncementsUpdated object:nil userInfo:@{courseId: courseId}];
            });
        };
        if ([teachersBeingLoaded count] == 0) teachersLoadedCompletion(saveError);
    }];
}

- (void)coursesWereUpdated {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"GCCourse"];
        NSError *err = nil;
        NSArray *result = [[[NSApp delegate] managedObjectContext] executeFetchRequest:fetchRequest error:&err];
        
        if (err) {
            NSLog(@"Failed to fetch local courses from Core Data: %@", err);
            _courses = @[];
        } else {
            self.courses = result; // EXC_BAD_ACCESS code=EXC_i386_GPFLT
            [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCClassesUpdated object:nil];
            //NSLog(@"result: %@", result);
            
        }
    });
}

- (void)announcementsWereUpdatedForCourse:(NSString*)courseId {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSFetchRequest* req = [NSFetchRequest fetchRequestWithEntityName:@"GCAnnouncement"];
        req.predicate = [NSPredicate predicateWithFormat:@"courseId == %@", courseId];
        req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"updateTime" ascending:NO]];
        req.relationshipKeyPathsForPrefetching = @[@"creatorUser"];
        NSError* err = nil;
        NSArray* result = [[(GCAppDelegate*)[NSApp delegate] managedObjectContext] executeFetchRequest:req error:&err];
        
        if (err) {
            NSLog(@"announcement fetch failed: %@", err);
            _announcements[courseId] = nil;
        } else {
            [self.announcements willChangeValueForKey:courseId];
            self.announcements[courseId] = result;
            [self.announcements didChangeValueForKey:courseId];
            [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCAnnouncementsUpdated object:nil userInfo:@{courseId: courseId}];
        }
    });
}


@end
