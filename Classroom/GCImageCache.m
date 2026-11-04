//
//  GCImageCache.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCImageCache.h"
#import <CommonCrypto/CommonDigest.h>

@implementation GCImageCache

+ (NSURL *)cacheFileForURL:(NSURL *)url {
    NSURL *dir = [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject]
                  URLByAppendingPathComponent:@"dev.atomtables.Classroom" isDirectory:YES];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    const char *str = [[url absoluteString] UTF8String];
    CC_SHA256(str, (CC_LONG)strlen(str), digest);
    NSMutableString *name = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [name appendFormat:@"%02x", digest[i]];
    return [dir URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"jpg"]];
}

+ (void)loadImageFromURL:(NSURL*)url completion:(void(^)(NSImage*, NSError*))comp {
    if (!url) {
        comp(nil, [NSError errorWithDomain:@"dev.atomtables.Classroom.nil-value" code:-1 userInfo:nil]);
        return;
    }
    
    NSURL* fileURL = [self cacheFileForURL:url];
    NSData* cached = [NSData dataWithContentsOfURL:fileURL];
    if (cached) {
        NSImage* image = [[NSImage alloc] initWithData:cached];
        if (image) { comp(image, nil); return; }
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    }

    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse* _, NSData* data, NSError* err) {
        NSImage *image = data ? [[NSImage alloc] initWithData:data] : nil;
        if (err || !image) {
            comp(nil, err ?: [NSError errorWithDomain:@"dev.atomtables.Classroom.bad-image" code:-2 userInfo:nil]);
            return;
        }
        comp(image, nil);
        
        NSError *writeError = nil;
        if ([[NSFileManager defaultManager] createDirectoryAtURL:[fileURL URLByDeletingLastPathComponent]
                                     withIntermediateDirectories:YES attributes:nil error:&writeError]
            && [data writeToURL:fileURL options:NSDataWritingAtomic error:&writeError]) return;
        NSLog(@"couldn't cache %@: %@", url, writeError);
    }];
}

@end
