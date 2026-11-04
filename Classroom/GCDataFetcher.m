//
//  GCDataFetcher.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCDataFetcher.h"
#import "GCLoginManager.h"

@interface GCDataFetcher ()

@property (nonatomic) dispatch_queue_t networkQueue;

@end

@implementation GCDataFetcher

+ (instancetype)main {
    static GCDataFetcher* item;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        item = [[GCDataFetcher alloc] init];
        item.networkQueue = dispatch_queue_create("dev.atomtables.Classroom.networkQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return item;
}

- (id)init {
    self = [super init];
    return self;
}

+ (NSMutableURLRequest*)makeAuthenticatedRequestWithURL:(NSString*)url {
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", [[GCLoginManager main] accessCode]] forHTTPHeaderField:@"Authorization"];
    NSLog(@"Authorization: %@", [req valueForHTTPHeaderField:@"Authorization"]);
    return req;
}

#pragma mark - HELPER

+ (GCCourse*)courseWithId:(NSString *)courseId context:(NSManagedObjectContext *)context {
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

// recursive function so keeping this private.
+ (void)pagedRequestTo:(NSString*)url token:(NSString*)pageToken arrayKey:(NSString*)arrayKey accumulation:(NSMutableArray*)arr completion:(void (^)(NSArray* courses, NSError*))comp {
    NSString* urlStr = url;
    if (pageToken) {
        NSString *separator = [urlStr rangeOfString:@"?"].location == NSNotFound ? @"&" : @"?";
        urlStr = [urlStr stringByAppendingFormat:@"%@pageToken=%@", separator, pageToken];
    }

    NSMutableURLRequest* req = [self makeAuthenticatedRequestWithURL:urlStr];
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse* res, NSData* data, NSError* error) {
        if (error) {
            NSLog(@"pagedRequestTo:%@ token:%@ accumulation:%@ completion: error occurred: %@ with response data (UTF8): %@", url, pageToken, arr, error, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            NSLog(@"request: %@, response: %@", req, res);
            comp(nil, error);
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError || ![jsonDict isKindOfClass:[NSDictionary class]]) {
            comp(nil, jsonError);
            return;
        }
        
        if (jsonDict[@"error"]) {
            comp(nil, [NSError errorWithDomain:@"GCDataFetcher" code:-3 userInfo:@{NSLocalizedDescriptionKey: [jsonDict[@"error"][@"message"] description] ?: @"API error"}]);
            return;
        }
        
        id items = jsonDict[arrayKey];
        if ([items isKindOfClass:[NSArray class]]) [arr addObjectsFromArray:items];
        
        NSString *nextPageToken = jsonDict[@"nextPageToken"];
        if (nextPageToken.length > 0) {
            [self pagedRequestTo:url token:nextPageToken arrayKey:arrayKey accumulation:arr completion:comp];
        } else {
            comp(arr, nil);
        }
    }];
}

//- (void)listAllTeachersInCourse:(NSString*)courseId token:(NSString*)pageToken completion:(void (^)(NSError*))comp {
//    NSString *urlStr = kGCAPICourseTeachersList(courseId);
//    if (pageToken) {
//        urlStr = [urlStr stringByAppendingFormat:@"&pageToken=%@", pageToken];
//    }
//    
//    NSMutableURLRequest* req = [self makeAuthenticatedRequestWithURL:urlStr];
//    
//    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse* res, NSData* data, NSError* error) {
//        if (error) {
//            NSLog(@"listAllTeachersInCourse: %@", error);
//            comp(error);
//            return;
//        }
//        
//        NSError *jsonError = nil;
//        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
//        
//        if (jsonError || ![jsonDict isKindOfClass:[NSDictionary class]]) {
//            comp(jsonError);
//            return;
//        }
//        if (jsonDict[@"error"]) {
//            comp([NSError errorWithDomain:@"GCDataFetcher" code:-3 userInfo:@{NSLocalizedDescriptionKey: [jsonDict[@"error"][@"message"] description] ?: @"API error"}]);
//            return;
//        }
//        
//        NSString *nextPageToken = safeValue(jsonDict[@"nextPageToken"]);
//        if (nextPageToken.length > 0) {
//            [self listAllTeachersInCourse:courseId token:nextPageToken completion:comp];
//        } else {
//            comp(nil);
//        }
//    }];
//}

#pragma mark - PUBLIC

//+ (BOOL)listTeachersInCourseId:(NSString*)courseId completion:(void (^)(NSArray* courses, NSError*))comp {
//    
//}

+ (BOOL)listAnnouncementsInCourse:(NSString*)courseId completion:(void (^)(NSArray* announcements, NSError*))comp {
    if (![[GCLoginManager main] accessCode].length) {
        comp(nil, [NSError errorWithDomain:@"GCDataFetcher" code:-1
                                  userInfo:@{NSLocalizedDescriptionKey: @"No access token yet"}]);
        return NO;
    }
    NSString* url = kGCAPICourseAnnouncementsList(courseId);
    [self pagedRequestTo:url token:nil arrayKey:@"announcements" accumulation:[[NSMutableArray alloc] init] completion:comp];
    return YES;
}

+ (BOOL)listCourses:(void (^)(NSArray* courses, NSError*))comp {
    if (![[GCLoginManager main] isAuthenticated] &&
        ![[[GCLoginManager main] authorisedScopes]
          containsObject:@"https://www.googleapis.com/auth/classroom.courses.readonly"]) {
            NSLog(@"user is not authenticated or does not have proper scopes");
            comp(nil, [[NSError alloc] initWithDomain:@"" code:-1 userInfo:nil]);
            return NO;
    }
    [self pagedRequestTo:kGCAPICoursesList token:nil arrayKey:@"courses" accumulation:[[NSMutableArray alloc] init] completion:^(NSArray* courses, NSError* err) {
        if (err){
            NSAlert* alert = [NSAlert alertWithError:err];
            [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse _){}];
            NSLog(@"error was received: %@", err);
        };
        comp(courses, err);
    }];
    return YES;
}

+ (BOOL)listTeachersInCourse:(NSString*)courseId completion:(void (^)(NSArray* teachers, NSError*))comp {
    if (![[GCLoginManager main] isAuthenticated] &&
        ![[[GCLoginManager main] authorisedScopes]
          containsObject:@"https://www.googleapis.com/auth/classroom.courses.readonly"]) {
            NSLog(@"user is not authenticated or does not have proper scopes");
            comp(nil, [[NSError alloc] initWithDomain:@"" code:-1 userInfo:nil]);
            return NO;
        }
    [self pagedRequestTo:kGCAPICourseTeachersList(courseId) token:nil arrayKey:@"teachers" accumulation:[[NSMutableArray alloc] init] completion:^(NSArray* teachers, NSError* err) {
        if (err){
            NSAlert* alert = [NSAlert alertWithError:err];
            [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse _){}];
            NSLog(@"error was received: %@", err);
        };
        comp(teachers, err);
    }];
    return YES;
}

+ (BOOL)getUserProfile:(NSString*)userId completion:(void (^)(NSDictionary* profile, NSError*))comp {
    NSString* url = kGCAPIProfileGet(userId);
    NSMutableURLRequest* req = [self makeAuthenticatedRequestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse* res, NSData* data, NSError* error) {
        if (error) { comp(nil, error); return; }
        NSDictionary* json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        if (![json isKindOfClass:[NSDictionary class]] || json[@"error"]) {
            comp(nil, [NSError errorWithDomain:@"GCDataFetcher"
                                          code:-3
                                      userInfo:@{NSLocalizedDescriptionKey: [json[@"error"][@"message"] description] ?: @"Bad response"}]
                 );
            return;
        }
        comp(json, nil);
    }];
    return YES;
}

@end
