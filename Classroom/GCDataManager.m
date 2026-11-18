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
#import "GCInnerSchemas.h"
#import "GCConstants.h"
#import <libkern/OSAtomic.h>

int MAX_CACHING_PERIOD = 30;

#pragma mark - Old functions for using GC API

NSString* GCAddHttpProtocolIfMissingToURLString(NSString* string) {
    NSString* urlString;
    if ([string hasPrefix:@"//"]) urlString = [NSString stringWithFormat:@"https:%@", string];
    else urlString = string ?: @"http://localhost:0";
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

#pragma mark - gRPC Schema Functions

// GCSchemaCheck: compare a decoded response (NSArray) with the typed schema (v2)
// exported from Batch Data Explorer. Returns issue strings; an empty array means it matches.
//   NSDictionary *schema = [NSJSONSerialization JSONObjectWithData:[kGCSchemaJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
//   NSArray *issues = GCSchemaCheck(response, schema, NO);   // YES also reports values the schema does not cover
// GCValueAtPath(response, @[@6, @0, @"*"]) reads a mapped value; @"*" means the first item.
static NSString *GCTypeName(id v) {
    if (v == nil || v == [NSNull null]) return @"null";
    if ([v isKindOfClass:[NSString class]]) return @"string";
    if ([v isKindOfClass:[NSNumber class]])
        return CFGetTypeID((__bridge CFTypeRef)v) == CFBooleanGetTypeID() ? @"bool" : @"number";
    if ([v isKindOfClass:[NSArray class]]) return @"array";
    if ([v isKindOfClass:[NSDictionary class]]) return @"object";
    return @"unknown";
}
static void GCCheckNode(id value, NSDictionary *node, NSString *path, BOOL unmapped, NSMutableArray *issues) {
    NSArray *types = [node[@"types"] isKindOfClass:[NSArray class]] ? node[@"types"] : @[];
    NSString *actual = GCTypeName(value);
    if (types.count && ![types containsObject:@"any"] && ![types containsObject:actual]) {
        id nm = node[@"name"];
        NSString *label = [nm isKindOfClass:[NSString class]] ? [NSString stringWithFormat:@" (%@)", nm] : @"";
        [issues addObject:[NSString stringWithFormat:@"%@%@: expected %@, got %@%@", path, label,
                           [types componentsJoinedByString:@"|"], actual, [actual isEqualToString:@"null"] ? @" (missing or null)" : @""]];
        return;
    }
    if (![value isKindOfClass:[NSArray class]]) return;
    NSArray *arr = value;
    NSDictionary *item = node[@"item"];
    if ([item isKindOfClass:[NSDictionary class]])
        for (NSUInteger i = 0; i < arr.count; i++)
            GCCheckNode(arr[i], item, [path stringByAppendingFormat:@"[%lu]", (unsigned long)i], unmapped, issues);
    NSArray *kids = node[@"children"];
    if (![kids isKindOfClass:[NSArray class]]) return;
    for (NSUInteger i = 0; i < kids.count; i++) {
        if (![kids[i] isKindOfClass:[NSDictionary class]]) continue;
        GCCheckNode(i < arr.count ? arr[i] : nil, kids[i], [path stringByAppendingFormat:@"[%lu]", (unsigned long)i], unmapped, issues);
    }
    if (unmapped)
        for (NSUInteger i = 0; i < arr.count; i++) {
            BOOL covered = i < kids.count && [kids[i] isKindOfClass:[NSDictionary class]];
            if (!covered && arr[i] != [NSNull null])
                [issues addObject:[NSString stringWithFormat:@"%@[%lu]: unmapped %@ value", path, (unsigned long)i, GCTypeName(arr[i])]];
        }
}
NSArray *GCSchemaCheck(NSArray *data, NSDictionary *schema, BOOL reportUnmapped) {
    NSMutableArray *issues = [NSMutableArray array];
    if (![schema isKindOfClass:[NSDictionary class]] || [schema[@"version"] integerValue] != 2 ||
        ![schema[@"root"] isKindOfClass:[NSDictionary class]]) {
        [issues addObject:@"schema: missing or unsupported version (expected 2)"];
        return issues;
    }
    GCCheckNode(data, schema[@"root"], @"$", reportUnmapped, issues);
    return issues;
}
id GCValueAtPath(id data, NSArray *path) {
    id cur = data;
    for (id seg in path) {
        if (![cur isKindOfClass:[NSArray class]]) return nil;
        NSArray *a = cur;
        NSUInteger i = [seg isKindOfClass:[NSNumber class]] ? [seg unsignedIntegerValue] : 0;
        if (i >= a.count) return nil;
        cur = a[i];
    }
    return cur == [NSNull null] ? nil : cur;
}

#pragma mark - more AI functions to help normalise schema

// ---- GCHelpers.h: shared by every normaliser (needs GCValueAtPath from the Mapping tab) ----
// Returns v only if it is of class cls. nil and NSNull pass through as nil without a warning.
// Anything else logs the calling function and line, then returns nil.
static id GCExpect(id v, Class cls, const char *fn, int line) {
    if (v == nil || v == [NSNull null]) return nil;
    if ([v isKindOfClass:cls]) return v;
    NSLog(@"GC type warning: %s line %d expected %@ but got %@ (%@)", fn, line, NSStringFromClass(cls), NSStringFromClass([v class]), v);
    return nil;
}
#define GCStr(v) ((NSString *)GCExpect((v), [NSString class], __PRETTY_FUNCTION__, __LINE__))
#define GCNum(v) ((NSNumber *)GCExpect((v), [NSNumber class], __PRETTY_FUNCTION__, __LINE__))
#define GCArr(v) ((NSArray *)GCExpect((v), [NSArray class], __PRETTY_FUNCTION__, __LINE__))

// Value of `key` from the paths dictionary. `from` is the object at the path of `under` + @"*"
// (pass the root data with under = nil).
// basically instead of passing raw values we can use the bs that claude generated for me
static id GCField(id from, NSDictionary *paths, NSString *key, NSString *under) {
    NSArray *full = paths[key];
    NSUInteger skip = 0;
    if (under) {
        skip = [paths[under] count];
        if (skip < full.count && [full[skip] isEqual:@"*"]) skip++;
    }
    if (!full || full.count < skip) { NSLog(@"GCField: no path named %@ under %@", key, under); return nil; }
    return GCValueAtPath(from, [full subarrayWithRange:NSMakeRange(skip, full.count - skip)]);
}

// `from` is the object at paths[inside] (same convention as GCField)
static id GCShapeRoot(id from, NSDictionary *paths, NSString *shape, NSString *inside) {
    NSArray *base = paths[inside];
    for (NSArray *use in paths[[shape stringByAppendingString:@"@uses"]])
        if (use.count > base.count && [[use subarrayWithRange:NSMakeRange(0, base.count)] isEqualToArray:base])
            return GCValueAtPath(from, [use subarrayWithRange:NSMakeRange(base.count, use.count - base.count)]);
    NSLog(@"GCShapeRoot: no %@ inside %@", shape, inside);
    return nil;
}
static id GCShapeField(id root, NSDictionary *paths, NSString *key, NSString *shape) {
    NSArray *p = paths[[NSString stringWithFormat:@"%@.%@", shape, key]];
    if (!p) { NSLog(@"GCShapeField: no field %@ in shape %@", key, shape); return nil; }
    return GCValueAtPath(root, p);
}

static NSDate *GCDateFromMs(NSNumber *ms) {
    return ms ? [NSDate dateWithTimeIntervalSince1970:ms.doubleValue / 1000.0] : nil;
}



#pragma mark - DataManager

@interface GCDataManager ()
@property (nonatomic, readwrite) NSMutableDictionary* announcements;
@property (nonatomic, readwrite) NSArray* courses;
@end

@implementation GCDataManager {
    NSTimer* classUpdateTimer;
    NSArray* _courses;
    dispatch_queue_t networkQueue;
    
    NSMutableSet* announcementsInFlight;
    int32_t userProfilesBeingLoaded;
    NSMutableArray* userProfilesLoadedCompletion;
    
    NSManagedObjectContext* importContext;
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
    announcementsInFlight = [[NSMutableSet alloc] init];
    
    importContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    importContext.parentContext = [(GCAppDelegate*)[NSApp delegate] managedObjectContext];
    importContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    
    classUpdateTimer = [NSTimer timerWithTimeInterval:30*60 target:self selector:@selector(updateCourses) userInfo:nil repeats:true];
    userProfilesLoadedCompletion = [[NSMutableArray alloc] init];
    [classUpdateTimer fire];
    
    [[NSRunLoop mainRunLoop] addTimer:classUpdateTimer forMode:NSDefaultRunLoopMode];
    
    [[GCLoginManager main] addObserver:self
                            forKeyPath:@"isAuthenticated"
                               options:NSKeyValueObservingOptionNew
                               context:nil];
    
    return self;
}

// call on importContext's queue, after saving it
- (void)pushImportToDisk {
    NSManagedObjectContext* main = [(GCAppDelegate*)[NSApp delegate] managedObjectContext];
    [main performBlock:^{
        NSError* e = nil;
        if ([main hasChanges] && ![main save:&e]) NSLog(@"main save failed: %@", e);
    }];
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

- (GCUserProfile*)getUserProfileWithId:(NSString*)userId context:(NSManagedObjectContext*)context {
    if (!userId || userId.length == 0) return nil;
    
/*    [context performBlockAndWait:^{
        NSFetchRequest* fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"GCUserProfile"];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"id == %@", userId];
        fetchRequest.fetchLimit = 1;
        
        NSError* error = nil;
        GCUserProfile* profile = [[context executeFetchRequest:fetchRequest error:&error] firstObject];
        
        if (!profile) {
            profile = [NSEntityDescription insertNewObjectForEntityForName:@"GCUserProfile"
                                                    inManagedObjectContext:context];
            profile.id = userId;
            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [teachersBeingLoaded addObject:userId];
//            });

            [[GCDataFetcher main] getUserProfile:userId completion:^(NSArray* item, NSError* error) {
                if (error) {
                    NSLog(@"Error loading user profile %@: %@", userId, error);
                }
                
                // because we only loaded one profile there should only be one item.
                [context performBlock:^{
                    NSDictionary* paths = GCSchemaFor(kgRPCListPeople);
                    NSManagedObjectContext* context = [(GCAppDelegate*)[NSApp delegate] managedObjectContext];
                    
                    NSArray* item2 = GCArr(GCArr(GCField(item, paths, @"data", nil)).firstObject);
                    
                    profile.name = GCStr(GCField(item2, paths, @"fullName", @"data"));
                    profile.emailAddress = GCStr(GCField(item2, paths, @"email", @"data"));
                    profile.photoUrl = GCAddHttpProtocolIfMissingToURLString(GCStr(GCField(item2, paths, @"pfp", @"data")));
                    profile.me = GCNum(GCField(item2, paths, @"me", @"data"));
                    
                    NSError *saveError = nil;
                    if ([context hasChanges]) {
                        [context save:&saveError];
                    }
                    
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [teachersBeingLoaded removeObject:userId];
//                        if ([teachersBeingLoaded count] == 0 && teachersLoadedCompletion) {
//                            NSLog(@"teachersLoadedCompletion ran");
////                            teachersLoadedCompletion(nil);
//                        }
//                    });
                    [self coursesWereUpdated];
                }];
            }];
        }
        
        ret = profile;
    }];*/
    
    NSArray* result = [self getUserProfilesWithIds:@[userId] context:context];
    NSAssert(result.count == 1, @"getUserProfilesWithId:context: did not return ONE result when it was required to by getUserProfileWithId:context:");
    
    return result[0];
}

// NSArray of GCUserProfiles is to be returned
- (NSArray*)getUserProfilesWithIds:(NSArray*)userIds context:(NSManagedObjectContext*)context {
    if (!userIds || userIds.count == 0) return nil;
    NSMutableOrderedSet* wanted = [NSMutableOrderedSet orderedSetWithArray:userIds];
    
    NSMutableDictionary* byId = [NSMutableDictionary dictionary];
    NSMutableArray* toLoad = [NSMutableArray array];
    __block NSArray* ret = nil;
    
    [context performBlockAndWait:^{
        NSFetchRequest* fr = [NSFetchRequest fetchRequestWithEntityName:@"GCUserProfile"];
        fr.predicate = [NSPredicate predicateWithFormat:@"id IN %@", wanted.array];
        for (GCUserProfile* p in [context executeFetchRequest:fr error:NULL]) byId[p.id] = p;
        
        for (NSString* uid in wanted) {
            GCUserProfile* p = byId[uid];
            if (!p) {
                p = [NSEntityDescription insertNewObjectForEntityForName:@"GCUserProfile" inManagedObjectContext:context];
                p.id = uid;
                byId[uid] = p;
            }
            if (!p.name) [toLoad addObject:uid];
        }
        ret = [byId objectsForKeys:wanted.array notFoundMarker:[NSNull null]];
    }];
    
    if (toLoad.count) {
        OSAtomicAdd32((int)toLoad.count, &userProfilesBeingLoaded);
        [[GCDataFetcher main] getUserProfiles:toLoad completion:^(NSArray* response, NSError* error) {
            if (error || !response) {
                NSLog(@"loading %lu user profiles failed: %@", (unsigned long)toLoad.count, error);
                return;
            }
            NSDictionary* paths = GCSchemaFor(kgRPCListPeople);
            [context performBlock:^{
                for (NSArray* item in GCArr(GCField(response, paths, @"data", nil))) {
                    NSString* uid = GCStr(GCField(item, paths, @"str", @"data"));
                    GCUserProfile* p = uid ? byId[uid] : nil;
                    if (!p) { NSLog(@"WARNING: profile response had an id we did not ask for: %@", item); continue; }
                    
                    p.name = GCStr(GCField(item, paths, @"fullName", @"data"));
                    p.emailAddress = GCStr(GCField(item, paths, @"email", @"data"));
                    p.photoUrl = GCAddHttpProtocolIfMissingToURLString(GCStr(GCField(item, paths, @"pfp", @"data")));
                    p.me = GCNum(GCField(item, paths, @"me", @"data"));
                }
                NSError* saveError = nil;
                if ([context hasChanges] && ![context save:&saveError]) NSLog(@"saving profiles failed: %@", saveError);
                [self pushImportToDisk];

                if (OSAtomicAdd32((int)-toLoad.count, &userProfilesBeingLoaded) == 0) {
                    NSLog(@"userProfilesBeingLoaded is now zero. %lu handlers to run.", (unsigned long)userProfilesLoadedCompletion.count);
                    for (void(^func)(void) in userProfilesLoadedCompletion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            func();
                        });
                    }
                    [userProfilesLoadedCompletion removeAllObjects];
                }
            }];
        }];
    }
    
    return ret;
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
    [[GCDataFetcher main] listCourses:^(NSArray* courses, NSError* err) {
        if (err) {
            NSLog(@"course refresh failed for %@:", err);
            return;
        }
        
        [[[NSApp delegate] managedObjectContext] performBlock:^{
            NSDictionary *paths = GCSchemaFor(kgRPCListCourses);
            NSMutableArray* arr = [[NSMutableArray alloc] init];
            NSManagedObjectContext* context = [(GCAppDelegate*)[NSApp delegate] managedObjectContext];
            //        NSLog(@"courses: %@", courses);
            //        NSLog(@", courses[0][2][2]: %@", courses[0][2][2]);
            //        NSLog(@" gcfield method: %@", GCArr(GCField(courses, paths, @"courses", nil)));
            NSArray* items = GCArr(GCField(courses, paths, @"courses", nil));
            for (int i = 0; i < items.count; i++) {
                NSArray* item = items[i];
                NSString* courseId = GCStr(GCField(item, paths, @"str", @"courses"));
                if (!courseId) {
                    NSLog(@"WARNING: while loading courses, found a course without a courseId.");
                    NSLog(@"Course data: %@", item);
                    continue;
                };
                
                GCCourse* course = [self courseWithId:courseId context:context];
                
                course.id                = courseId;
                course.name              = GCStr(GCField(item, paths, @"name", @"courses"));
                course.section           = GCStr(GCField(item, paths, @"section", @"courses"));
                course.courseDescription = GCStr(GCField(item, paths, @"description", @"courses"));
                course.room              = GCStr(GCField(item, paths, @"room", @"courses"));
                course.enrollmentCode    = GCStr(GCField(item, paths, @"joinCode", @"courses"));
                course.subject           = GCStr(GCField(item, paths, @"subject", @"courses"));
                course.orderToken        = GCStr(GCField(item, paths, @"locationToken", @"courses"));
                if (course.orderToken) {                           // CHANGE 2: guard nil
                    NSData* decodedData = [[NSData alloc] initWithBase64EncodedString:course.orderToken options:0];
                    const unsigned char* bytes = [decodedData bytes];
                    double sortValue = 0.0;
                    for (NSUInteger i = 0; i < decodedData.length; i++) sortValue += bytes[i] / pow(256.0, i + 1);
                    course.orderTokenSortable = @(sortValue);
                }
                course.courseState       = GCNum(GCField(item, paths, @"courseState", @"courses"));
                course.classRole         = GCNum(GCField(item, paths, @"role", @"courses"));
                course.creationTime      = GCDateFromMs(GCNum(GCField(item, paths, @"createTime", @"courses")));
                course.updateTime        = GCDateFromMs(GCNum(GCField(item, paths, @"updateTime", @"courses")));
                
                course.colorPrimary      = GCStr(GCField(item, paths, @"primary", @"courses"));
                course.colorBackground   = GCStr(GCField(item, paths, @"background", @"courses"));
                course.colorForeground   = GCStr(GCField(item, paths, @"foreground", @"courses"));
                course.colorShouldAdjustContrast = GCNum(GCField(item, paths, @"shouldShowWhiteOverlay", @"courses"));
                course.colorFavicon      = GCStr(GCField(item, paths, @"faviconForPage", @"courses"));
                course.banner            = GCStr(GCField(item, paths, @"customBannerUrl", @"courses"))
                ?: GCStr(GCField(item, paths, @"bannerUrl", @"courses"));
                
                NSString *teacherId = GCStr(GCField(item, paths, @"id_3", @"courses"));
                [course addTeacherObject:[self getUserProfileWithId:teacherId context:context]];
                
                // we will set this at the last point we might need to load data.
                if (i == items.count - 1) {
                    GCDataManager* __weak weakSelf = self;
                    [userProfilesLoadedCompletion addObject:^{
                        NSLog(@"setting self courses now");
                        weakSelf.courses = arr;
                    }];
                }
                
                NSMutableArray* studentsToLoad = [[NSMutableArray alloc] init];
                for (id student in GCArr(GCField(item, paths, @"students", @"courses"))) {
                    NSString* sid = GCStr(GCField(student, paths, @"id_4", @"students"));
                    if (sid) [studentsToLoad addObject:sid];
                }
                if (studentsToLoad.count) [course addStudents:[NSSet setWithArray:[self getUserProfilesWithIds:studentsToLoad context:context]]];
                
                [arr addObject:course];
            }
            
            NSSet* returnedIds = [NSSet setWithArray:[arr valueForKey:@"id"]];
            NSFetchRequest* stale = [NSFetchRequest fetchRequestWithEntityName:@"GCCourse"];
            stale.predicate = [NSPredicate predicateWithFormat:@"NOT (id IN %@)", returnedIds];
            for (GCCourse* old in [context executeFetchRequest:stale error:NULL]) {
                [context deleteObject:old];
            }
            
            NSError *saveError = nil;
            if ([context hasChanges]) {
                [context save:&saveError];
            }
            [self pushImportToDisk];
            
            // stupid ahh code wwon't allow this to be weak...
            
//            teachersLoadedCompletion = ^(NSError* error) {
//                NSLog(@"loading teachersLoadedCompletion");
//                if (error) {
//                    NSLog(@"an error occurred to teachersLoadedCompletion: %@", error);
//                }
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    ; // Triggers KVO
//                    [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCClassesUpdated object:nil];
//                });
////                weakSelf->teachersLoadedCompletion = nil;
//            };
            //        if ([teachersBeingLoaded count] == 0)
//            teachersLoadedCompletion(saveError);
            NSLog(@"loaded self.courses");
        }];
    }];
}
- (void)updateAnnouncementsForCourseId:(NSString*)courseId {
    if (courseId.length == 0) return;
    
    [[[NSApp delegate] managedObjectContext] performBlock:^{
        NSFetchRequest* req = [NSFetchRequest fetchRequestWithEntityName:@"GCAnnouncement"];
        req.predicate = [NSPredicate predicateWithFormat:@"course.id == %@", courseId];
        req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"updateTime" ascending:NO]];
        req.relationshipKeyPathsForPrefetching = @[@"author"];
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
    }];
    
    if ([announcementsInFlight containsObject:courseId]) return;
    [announcementsInFlight addObject:courseId];
    
    [[GCDataFetcher main] listAllAnnouncementsInCourse:courseId completion:^(NSArray* rawarraydata, NSError* err) {
        [announcementsInFlight removeObject:courseId];
        if (err) {
            NSLog(@"announcement refresh failed for %@: %@", courseId, err);
            return;
        }
        
        [importContext performBlockAndWait:^{
            NSDictionary *paths = GCSchemaFor(kgRPCListStreamForClass);
            NSMutableArray* arr = [[NSMutableArray alloc] init];
            NSManagedObjectContext* context = importContext;
            NSMutableDictionary* userProfileLoaded = [NSMutableDictionary dictionary];
            //        NSLog(@"courses: %@", courses);
            //        NSLog(@", courses[0][2][2]: %@", courses[0][2][2]);
            //        NSLog(@" gcfield method: %@", GCArr(GCField(courses, paths, @"courses", nil)));
            NSArray* items = GCArr(GCField(rawarraydata, paths, @"data", nil));
            for (int i = 0; i < items.count; i++) {
                NSNumber* type = GCNum(GCField(items[i], paths, @"type", @"data"));
                if ([type integerValue] != 3) {
                    NSLog(@"WARNING: while loading announcements, got something that doesn't have the correct type");
                    NSLog(@"Announcement data: %@", items[i]);
                    continue;
                }
                NSArray* item = GCArr(GCField(items[i], paths, @"announcement", @"data"));
                NSArray* post = GCArr(GCShapeRoot(item, paths, @"post", @"announcement"));
                NSString* announcementId = GCStr(GCShapeField(post, paths, @"id", @"post"));
                if (!announcementId) {
                    NSLog(@"WARNING: while loading announcements, found an announcement without a announcementId.");
                    NSLog(@"Announcement data: %@", item);
                    continue;
                };
                
                GCAnnouncement* announcement = [self announcementWithId:announcementId context:context];
                
                announcement.id         = announcementId;
                announcement.course     = [self courseWithId:GCStr(GCShapeField(post, paths, @"courseId", @"post")) context:context];
                announcement.createTime = GCDateFromMs(GCNum(GCShapeField(post, paths, @"createTime", @"post")));
                announcement.updateTime = GCDateFromMs(GCNum(GCShapeField(post, paths, @"updateTime", @"post")));
                announcement.editTime   = GCDateFromMs(GCNum(GCShapeField(post, paths, @"editedTime", @"post")));
                announcement.title      = GCStr(GCShapeField(post, paths, @"title", @"post"));
                announcement.publishedStatus
                                        = GCNum(GCShapeField(post, paths, @"publishedStatus", @"post"));
                
                NSString* publisher     = GCStr(GCShapeField(post, paths, @"publisherId", @"post"));
                if (!publisher)publisher= GCStr(GCShapeField(post, paths, @"authorId", @"post"));
                id val;
                if ((val = [userProfileLoaded objectForKey:publisher])) {
                    announcement.author     = val;
                }
                else {
                    val = [self getUserProfileWithId:publisher context:context];
                    [userProfileLoaded setObject:val forKey:publisher];
                    announcement.author     = val;
                }
                announcement.publishTime= GCDateFromMs(GCNum(GCShapeField(post, paths, @"publishedTime", @"post")));
                announcement.sortingTime= GCDateFromMs(GCNum(GCShapeField(post, paths, @"sortingTime", @"post")));
                announcement.integrationName
                                        = GCStr(GCShapeField(post, paths, @"integrationName", @"post"));
                announcement.apiId      = GCStr(GCShapeField(post, paths, @"apiId", @"post"));
                announcement.topicId    = GCStr(GCShapeField(post, paths, @"topicId", @"post"));
                announcement.isTargeted = GCNum(GCShapeField(post, paths, @"isTargeted", @"post"));
                announcement.orderToken = GCStr(GCShapeField(post, paths, @"orderToken", @"post"));
                announcement.plainText  = GCStr(GCShapeField(post, paths, @"plainText", @"post"));
                
                announcement.richText   = GCStr(GCShapeField(post, paths, @"richText", @"post"));
                
                [arr addObject:announcement];
            }
            
            NSSet* returnedIds = [NSSet setWithArray:[arr valueForKey:@"id"]];
            NSFetchRequest* stale = [NSFetchRequest fetchRequestWithEntityName:@"GCAnnouncement"];
            stale.predicate = [NSPredicate predicateWithFormat:@"course.id == %@ AND NOT (id IN %@)", courseId, returnedIds];
            for (GCCourse* old in [context executeFetchRequest:stale error:NULL]) {
                [context deleteObject:old];
            }
            
            NSError *saveError = nil;
            if ([context hasChanges]) {
                [context save:&saveError];
            }
            [self pushImportToDisk];
            
            // there's the likelihood we're not loading any user profiles
            // so let's check for that
            NSLog(@"userProfilesBeingLoaded before: %d", userProfilesBeingLoaded);
            if (userProfilesBeingLoaded == 0) {
                NSLog(@"loaded announcements FINALLY (user = 0)");
                [self.announcements willChangeValueForKey:courseId];
                self.announcements[courseId] = arr;
                [self.announcements didChangeValueForKey:courseId];
                [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCAnnouncementsUpdated object:nil userInfo:@{courseId: courseId}];
            } else {
                GCDataManager* __weak weakSelf = self;
                [userProfilesLoadedCompletion addObject:^{
                    NSLog(@"loaded announcements FINALLY (waited completion)");
                    [weakSelf.announcements willChangeValueForKey:courseId];
                    weakSelf.announcements[courseId] = arr;
                    [weakSelf.announcements didChangeValueForKey:courseId];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCAnnouncementsUpdated object:nil userInfo:@{courseId: courseId}];
                }];
            }
            NSLog(@"userProfilesBeingLoaded after: %d", userProfilesBeingLoaded);
            
            // stupid ahh code wwon't allow this to be weak...
            
            //            teachersLoadedCompletion = ^(NSError* error) {
            //                NSLog(@"loading teachersLoadedCompletion");
            //                if (error) {
            //                    NSLog(@"an error occurred to teachersLoadedCompletion: %@", error);
            //                }
            //                dispatch_async(dispatch_get_main_queue(), ^{
            //                    ; // Triggers KVO
            //                    [[NSNotificationCenter defaultCenter] postNotificationName:kGCNCClassesUpdated object:nil];
            //                });
            ////                weakSelf->teachersLoadedCompletion = nil;
            //            };
            //        if ([teachersBeingLoaded count] == 0)
            //            teachersLoadedCompletion(saveError);
            NSLog(@"loaded self.announcements[%@]", courseId);
        }];
        
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


@end
