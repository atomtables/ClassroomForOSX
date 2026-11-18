//
//  GCDataFetcher.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCDataFetcher.h"
#import "GCLoginManager.h"
#import "GCAppDelegate.h"
#import "GCMainWindow.h"

#define null [NSNull null]

@interface GCDataFetcher ()

@property (nonatomic) NSOperationQueue* opQueue;
@property (nonatomic) dispatch_queue_t networkQueue;

@property (atomic) BOOL inited;
@property (nonatomic, strong) NSString* bl;
@property (nonatomic, strong) NSString* fsid;
@property (nonatomic, strong) NSString* attoken;
@property (nonatomic, strong) NSString* batchEndpoint;

@end

#define okForHTTP [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"]


@implementation GCDataFetcher {
    id timer;
    int reqid;
    dispatch_semaphore_t semaphore;
}

+ (instancetype)main {
    static GCDataFetcher* item;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        item = [[GCDataFetcher alloc] init];
    });
    return item;
}

- (id)init {
    self = [super init];
    self.networkQueue = dispatch_queue_create("dev.atomtables.Classroom.networkQueue", DISPATCH_QUEUE_CONCURRENT);
    self.opQueue = [[NSOperationQueue alloc] init];
    semaphore = dispatch_semaphore_create(0);
    
    reqid = (rand() % 10000);
    
    return self;
}

#pragma mark - HELPERS

- (NSMutableURLRequest*)makeAuthenticatedRequestWithURL:(NSString*)url {
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    [req setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:153.0) Gecko/20100101 Firefox/153.0" forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [req setValue:@"1" forHTTPHeaderField:@"x-same-domain"];
    [req setValue:@"classroom.google.com" forHTTPHeaderField:@"Alt-Used"];
    [req setValue:@"empty" forHTTPHeaderField:@"Sec-Fetch-Dest"];
    [req setValue:@"cors" forHTTPHeaderField:@"Sec-Fetch-Mode"];
    [req setValue:@"same-origin" forHTTPHeaderField:@"Sec-Fetch-Site"];
    [req setValue:@"u=4" forHTTPHeaderField:@"Priority"];
    [req setValue:@"no-cache" forHTTPHeaderField:@"Pragma"];
    [req setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    [req setValue:@"https://classroom.google.com" forHTTPHeaderField:@"Origin"];
    [req setValue:cookies() forHTTPHeaderField:@"Cookie"];
    
    reqid += 100000;
    
    return req;
}

- (BOOL)retrieveRequiredValuesFromScrapedGoogleClassroomPage {
    NSMutableURLRequest* req = [self makeAuthenticatedRequestWithURL:@"https://classroom.google.com/u/7/h/st"];
    NSURLResponse* res;
    NSError* err;
    NSData* data = [NSURLConnection sendSynchronousRequest:req returningResponse:&res error:&err];
    
    if (err || ((NSHTTPURLResponse*)res).statusCode != 200) {
        dispatch_async(dispatch_get_main_queue(), ^{[[NSAlert alertWithError:err] beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse _){}];});
        NSLog(@"retrieveRequiredValuesFromScrapedGoogleClassroomPage err: %@", err);
        NSLog(@"the data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        dispatch_semaphore_signal(semaphore);
        return NO;
    }
    
    NSString* dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSRange start = [dataString rangeOfString:@"window.WIZ_global_data = "];
    if (start.location == NSNotFound) {
        NSLog(@"retrieveRequiredValuesFromScrapedGoogleClassroomPage err: values not found for WIZ_GLOBAL_DATA");
        dispatch_semaphore_signal(semaphore);
        return NO;
    }
    NSRange end = [dataString rangeOfString:@"\"};</script>" options:0 range:NSMakeRange(start.location, dataString.length - start.location)];
    
    NSString* item = [dataString substringWithRange:NSMakeRange(start.location + start.length, end.location - start.location - start.length + 2)];
    NSDictionary* wizGlobalData = [NSJSONSerialization JSONObjectWithData:[item dataUsingEncoding:NSUTF8StringEncoding]
                                                                  options:0
                                                                    error:&err];
    if (err) {
        [[NSAlert alertWithError:err] beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse _){}];
        NSLog(@"retrieveRequiredValuesFromScrapedGoogleClassroomPage err: %@", err);
        return NO;
    }
    
    self.bl = wizGlobalData[@"cfb2h"];
    self.fsid = wizGlobalData[@"FdrFJe"];
    self.attoken = wizGlobalData[@"SNlM0e"];
    self.batchEndpoint = wizGlobalData[@"Im6cmf"];
    NSAssert(self.bl, @"wiz_global_data.bl was null. Data was read successfully.");
    NSAssert(self.fsid, @"wiz_global_data.fsid was null. Data was read successfully.");
    NSAssert(self.attoken, @"wiz_global_data.attoken was null. Data was read successfully.");
    NSAssert(self.batchEndpoint, @"wiz_global_data.batchEndpoint was null. Data was read successfully.");
    self.inited = true;
    
    NSLog(@"loaded the retrieve: bl %@ fsid %@ attoken %@", self.bl, self.fsid, self.attoken);
    return YES;
}

- (void)makeBatchExecuteCallTo:(NSString*)_id body:(NSArray*)body comp:(void (^)(NSArray* courses, NSError*))comp {
    dispatch_async(self.networkQueue, ^{
        if (!self.inited) return;
        NSMutableURLRequest* req = [self makeAuthenticatedRequestWithURL:[NSString stringWithFormat:@"https://classroom.google.com%@/data/batchexecute?rpcids=%@&source-path=%@&f.sid=%@&hl=en&_reqid=%d&bl=%@", self.batchEndpoint, _id, [@"/u/7/h/st" stringByAddingPercentEncodingWithAllowedCharacters:okForHTTP], self.fsid, reqid, self.bl]];
        
        NSError* err;
        NSString* jsonData = [[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:body options:0 error:&err] encoding:NSUTF8StringEncoding]stringByAddingPercentEncodingWithAllowedCharacters:okForHTTP];
        NSData* bodyData = [[NSString stringWithFormat:@"f.req=%@&at=%@&", jsonData, [self.attoken stringByAddingPercentEncodingWithAllowedCharacters:okForHTTP]] dataUsingEncoding:NSUTF8StringEncoding];
        if (err) {
            NSLog(@"there was an error forming a request: %@", err);
            abort();
        }
        
        [req setHTTPMethod:@"POST"];
        [req setValue:@"application/x-www-form-urlencoded;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [req setHTTPBody:bodyData];
        
        [NSURLConnection sendAsynchronousRequest:req queue:self.opQueue completionHandler:^(NSURLResponse* res, NSData* data, NSError* err) {
            if (err){
                NSAlert* alert = [NSAlert alertWithError:err];
                dispatch_async(dispatch_get_main_queue(), ^{[alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse _){}];});
                NSLog(@"error was received: %@", err);
                comp(nil, err);
                return;
            };
            
            NSData* mdata = [data subdataWithRange:NSMakeRange(4, [data length] - 4)];
            
            // we gotta parse out this array
            NSMutableArray* content = [[NSJSONSerialization JSONObjectWithData:mdata
                                                                       options:0
                                                                         error:&err] mutableCopy];
            if (err){
                NSAlert* alert = [NSAlert alertWithError:err];
                dispatch_async(dispatch_get_main_queue(), ^{[alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSModalResponse _){}];});
                NSLog(@"error was received decoding json: %@", err);
                comp(nil, err);
                return;
            };
            
            // the data at [0][2] must be non-null and non-empty for a request to succeed.
            if (content[0][2] == null || [content[0][2] isEqualToString:@"[]\n"]) {
                err = [NSError errorWithDomain:AppErrorDomain
                                          code:DataFetchFailedErrorCode
                                      userInfo:@{
                                                 NSLocalizedDescriptionKey: @"The client was unable to fetch the necessary data from the server. This may be due to a failure to recieve said data, or a server-side failure. Try again in a few minutes, or if this continues, report this as a bug. The server returned error code: %d"
                                                 }];
                NSLog(@"content[0][5][0]: %@", content[0][5][0]);
                NSLog(@"content[0][2]:%@", content[0][2]);
                comp(nil, err);
                return;
            }
            
            content[0] = [content[0] mutableCopy];
            content[0][2] = [NSJSONSerialization JSONObjectWithData:[content[0][2] dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:&err];
            
            comp(content, nil);
        }];
    });
}

#pragma mark - PUBLIC

- (BOOL)listCourses:(void (^)(NSArray*, NSError*))comp {
    [(GCMainWindow*)[[NSApp delegate] window] addLoadingItem:@"allCourses" type:@"courses"];
    
    NSArray* bodyJSON = @[@[@[kgRPCListCourses, @"[[null,null,1,1],[1,1,1,1,1,1,1,1,[null,1,null,1,null,1,[1,1,1,1,1,1],null,[1],1,1,1,1,[1,1],[1,1]],1,1,null,null,1,null,null,null,null,null,null,[1,1,1,1,1,1,1],1,null,null,1,null,null,null,[1,1],1,1,null,null,1,1,1,1,null,1,1,[null,null,null,null,1,1,null,null,1,null,null,null,null,null,null,null,null,1,1,1,1,1,1],null,[1,1,1],[1,1,null,1],1,1,1,[[[1,1,1],1],[[[1,1]]],1],null,1,[1,1],null,null,1,null,[null,null,1],1],[[null,[[1]]],null,null,[1,2,3],null,null,[1,2]]]", null, @"generic"]]];
    
    [self makeBatchExecuteCallTo:kgRPCListCourses body:bodyJSON comp:^(NSArray* courses, NSError* err) {
        if (err) NSLog(@"an error occurred listing courses: %@", err);
        NSLog(@"Courses have been fetched");
        comp(courses, err);
        [(GCMainWindow*)[[NSApp delegate] window] removeLoadingItem:@"allCourses" type:@"courses"];
    }];
    
    return YES;
}

- (BOOL)getUserProfile:(NSString*)userId completion:(void (^)(NSArray* profileData, NSError*))comp {
    return [self getUserProfiles:@[userId] completion:comp];
}
- (BOOL)getUserProfiles:(NSArray*)userIds completion:(void (^)(NSArray* profileData, NSError*))comp {
    for (NSString* userId in userIds) {
        [(GCMainWindow*)[[NSApp delegate] window] addLoadingItem:userId type:@"user profiles"];
    }
    
    NSError* err;
    NSMutableArray* refs = [NSMutableArray arrayWithCapacity:userIds.count];
    for (NSString* userId in userIds)
        [refs addObject:@[null, @[userId]]];
    NSArray* reqItem = @[
                          @[null, null, @1, @0],
                          @[@1, @1, null, @1, null, @1, null, null, @1, @1, @1, @1, null, null, @1],
                          @[@[null, refs]]
                          ];
    
    NSString* reqStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:reqItem options:0 error:&err] encoding:NSUTF8StringEncoding];
    NSArray* bodyJSON = @[@[@[kgRPCListPeople, reqStr, null, @"generic"]]];
    
    [self makeBatchExecuteCallTo:kgRPCListPeople body:bodyJSON comp:^(NSArray* item, NSError* err) {
        if (err) NSLog(@"an error occurred getting user profiles: %@", err);
        comp(item, err);
        for (NSString* userId in userIds) {
            [(GCMainWindow*)[[NSApp delegate] window] removeLoadingItem:userId type:@"user profiles"];
        }
    }];
    
    return YES;
}

- (BOOL)listAllAnnouncementsInCourse:(NSString *)courseId completion:(void (^)(NSArray *, NSError *))comp {
    [(GCMainWindow*)[[NSApp delegate] window] addLoadingItem:[NSString stringWithFormat:@"announcements:%@", courseId] type:@"announcements"];
    
    NSError* err;
    NSArray* reqItem = @[
                         @[@1000, null, @1, @0],
                         @[@[@[@1, @1, @1, @1, @1, null, null, @[@1, @1, @1, null, @1, @1, @1], @1, @1, @1, @1, @1, @1, null, null, null, null, @1, null, null, null, @1, @[@1], @1, @[null, null, @1, @1, @1, null, @1]], @[@1, @1, @1, @1, @1, @1, @[@1], @1, null, @[@1, @1], @1, @1, null, @1, @[@[@1, @1, @[], @[null, @1]], @1, @1], null, null, null, @1], @[@1, @1], @1, @[@1, @1]], @[@[@1, @1, @1, @1, @1, null, null, @[@1, @1, @1, null, @1, @1, @1],  @1, @1, @1, @1, @1, @1, null, null,  null, null, @1, null,  null,null, @1, @[@1], @1, @[null, null, @1, @1, @1, null, @1]]], @[@[@1, @1, @1, @1, @1, null, null, @[@1, @1, @1, null, @1, @1, @1], @1, @1, @1, @1, @1, @1, null, null, null, null, @1, null, null, null, @1, @[@1], @1, @[null, null, @1, @1, @1, null, @1]], @[@1, @1, @1, @1, @1, @1, @[@1], @1, null, @[@1, @1], @1, @1, null, @1, @[@[@1, @1, @[], @[null, @1]], @1, @1], null, null, null, @1], @[@1]], null, null, @[@[@1, @1, @1, @1, @1,  null, null, @[@1, @1, @1, null, @1, @1, @1], @1, @1, @1, @1, @1, @1, null, null, null, null, @1, null, null, null, @1, @[@1], @1, @[null, null, @1, @1, @1, null, @1]]]],
                         @[@[@[@2,@3], @[@[courseId]], @[@3], @[@2]]]
                         ];
    
    NSString* reqStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:reqItem options:0 error:&err] encoding:NSUTF8StringEncoding];
    NSArray* bodyJSON = @[@[@[kgRPCListStreamForClass, reqStr, null, @"generic"]]];
    
    [self makeBatchExecuteCallTo:kgRPCListStreamForClass body:bodyJSON comp:^(NSArray* courses, NSError* err) {
        if (err) NSLog(@"an error occurred listing announcements for course %@: %@", courseId, err);
        NSLog(@"Announcements for course %@ have been fetched", courseId);
        comp(courses, err);
        [(GCMainWindow*)[[NSApp delegate] window] removeLoadingItem:[NSString stringWithFormat:@"announcements:%@", courseId] type:@"announcements"];
    }];
    
    return YES;
}

@end

#undef null