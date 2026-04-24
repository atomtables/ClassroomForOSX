//
//  GCLoginManager.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "GCLoginManager.h"
#import "GCUserProfile.h"

#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

NSString* clientID = @""; // Your Client ID
NSString* clientSecret = @""; // Your Client secret


@interface GCLoginManager ()

// 0 when inactive, 1 when waiting, 2 when got code, 3 when code exchange, 4 when testing API
@property (nonatomic, readwrite) int step;
// user friendly status
@property (nonatomic, strong, readwrite) NSString* status;

// 1 on success, 0 on unknown, -1 on failure (ratio test much??? jkjk)
@property (nonatomic, readwrite) int success;
@property (nonatomic, readwrite) BOOL isAuthenticated;

@property (nonatomic) NSDate* expiry;
@property (nonatomic, strong) NSTimer *refreshTimer;

@property (nonatomic) int serverPort;
@property (nonatomic) int serverSocket;
@property (nonatomic, strong) dispatch_source_t listeningSource;

@end

@implementation GCLoginManager {
    NSString* codeChallenge;
    NSString* accountOwnerOld;
    NSDictionary* accountOld;
}

+ (instancetype)main {
    static GCLoginManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.step = 0;
        sharedInstance.success = 0;
    });
    return sharedInstance;
}

- (NSString*)generateCodeChallenge {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:64];
    for (NSUInteger i = 0; i < 64; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }
    
    codeChallenge = randomString;
    
    NSData *data = [randomString dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSData *hashData = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    
    // Base64-URL encode the hash
    NSString *base64 = [hashData base64EncodedStringWithOptions:0];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
    return base64;
}

- (void)runRedirectUri {
    [self updateStateWithStep:1 success:0 status:@"Waiting for user to authorise scopes."];
    
    NSString* scope = [
                       [
                        @[
                          @"profile",
                          @"email",
                          @"https://www.googleapis.com/auth/classroom.courses",
                          @"https://www.googleapis.com/auth/classroom.rosters",
                          @"https://www.googleapis.com/auth/classroom.profile.emails",
                          @"https://www.googleapis.com/auth/classroom.profile.photos",
                          @"https://www.googleapis.com/auth/classroom.coursework.students",
                          @"https://www.googleapis.com/auth/classroom.coursework.me",
                          @"https://www.googleapis.com/auth/classroom.topics",
                          @"https://www.googleapis.com/auth/classroom.announcements"
                          ]
                        componentsJoinedByString:@" "]
                       stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]
                       ];
    
    NSError* err = nil;
    [self startListeningWithCompletion:^(NSString* code) {[self stopListening];[self listenForRedirectUri:code];} andError:&err];
    
    if (err) {
        self.step = 0;
        self.success = -1;
        self.status = @"an error occured setting up redirect uri";
        [self stopListening];
    }
    
    NSURL* redirectUri = [NSURL URLWithString:[NSString stringWithFormat:
                             @"https://accounts.google.com/o/oauth2/v2/auth?client_id=%@&redirect_uri=%@&response_type=code&scope=%@&code_challenge=%@&code_challenge_method=S256",
                             [clientID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                             [[NSString stringWithFormat:@"http://localhost:%d/oauthredirect", self.serverPort] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                             scope,
                             [self generateCodeChallenge]
                             ]];
    
    [[NSWorkspace sharedWorkspace] openURL:redirectUri];
}

- (void)listenForRedirectUri:(NSString*)uri {
    [self updateStateWithStep:2 success:0 status:@"redirect URI"];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    NSURL* url = [NSURL URLWithString:uri];
    NSArray* queryComponents = [[url query] componentsSeparatedByString:@"&"];
    for (NSString* item in queryComponents) {
        NSArray* keyVal = [item componentsSeparatedByString:@"="];
        if ([keyVal[0] isEqual: @"code"]) {
            NSLog(@"code equal to %@", keyVal[1]);
            [self actualAuthentication:keyVal[1]];
        } else if ([keyVal[0] isEqual:@"error"]) {
            NSLog(@"error returned");
            self.success = -1;
        }
    }
}

- (void)actualAuthentication:(NSString*)code {
    [self updateStateWithStep:3 success:0 status:@"Exchanging code with Google..."];
    NSLog(@"now within auth point");
    NSMutableURLRequest* req = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://oauth2.googleapis.com/token"]];
    
    NSString* mainBody = [NSString stringWithFormat:@"code=%@&"
                          "client_id=%@&"
                          "client_secret=%@&"
                          "code_verifier=%@&"
                          "grant_type=authorization_code&"
                          "redirect_uri=%@",
                          code/*[ stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]*/, [clientID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], [clientSecret stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], [codeChallenge stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], [[NSString stringWithFormat:@"http://localhost:%d/oauthredirect", self.serverPort] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    [req setHTTPBody:[mainBody dataUsingEncoding:NSUTF8StringEncoding]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    NSLog(@"about to make connection!!! httpBody: %@", mainBody);
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session
                                  dataTaskWithRequest:req
                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSLog(@"made connection, continuing!!!");
                                      [self handleTokenNetworkResponseWithData:data error:error isRefresh:NO];
                                  }];
    [task resume];
}

- (void)handleTokenNetworkResponseWithData:(NSData *)data error:(NSError *)err isRefresh:(BOOL)isRefresh {
    if (err) {
        [self updateStateWithStep:0 success:-1 status:[NSString stringWithFormat:@"Network request failed: %@", err.localizedDescription]];
        NSLog(@"network request failed: %@", err.localizedDescription);
        return;
    }
    
    NSLog(@"got this far");
    
    NSError *jsonError;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    
    if (jsonError || ![dict isKindOfClass:[NSDictionary class]] || !dict[@"access_token"]) {
        NSLog(@"failed to parse json: dict was %@, error: %@", dict, jsonError);
        
        if (dict[@"error"]) {
            [self updateStateWithStep:0 success:-1 status:[NSString stringWithFormat:@"Server errored out during key exchange: %@.", dict[@"error_description"]]];
        } else {
            [self updateStateWithStep:0 success:-1 status:@"Server sent unexpected data. Check console for more info."];
        }
        
        // If a refresh explicitly fails due to a bad grant, force user to log in again
        if (isRefresh && [dict[@"error"] isEqualToString:@"invalid_grant"]) {
            self.isAuthenticated = NO;
        }
        return;
    }
    
    self.accessCode = dict[@"access_token"];
    NSTimeInterval expiresIn = [dict[@"expires_in"] doubleValue];
    self.expiry = [NSDate dateWithTimeIntervalSinceNow:expiresIn];
    NSLog(@"access code is %@ and expires in %@", self.accessCode, self.expiry);
    
    if (!isRefresh || (dict[@"id_token"] && !self.accountOwner)) {
        self.accountOwner = dict[@"id_token"];
    }
    
    NSLog(@"%@, %@", dict[@"id_token"], self.accountOwner);
    
    NSString *scopesStr = dict[@"scope"] ?: @"";
    self.authorisedScopes = [scopesStr componentsSeparatedByString:@" "];
    
    NSLog(@"scopes are %@", scopesStr);
    
    NSDictionary *genericInfo = @{
                                  @"expires_at": @([self.expiry timeIntervalSince1970]),
                                  @"scopes": scopesStr
                                  };
    
    NSLog(@"got this far again");
    
    [self saveKeychainItem:@"access_token" value:self.accessCode genericInfo:genericInfo];
    
    if (dict[@"refresh_token"]) {
        [self saveKeychainItem:@"refresh_token" value:dict[@"refresh_token"] genericInfo:nil];
        self.isAuthenticated = YES;
    }
    
    [self scheduleTokenRefresh];
    [self updateStateWithStep:4 success:1 status:@"Successfully authenticated."];
}

- (NSString*)accountOwner {
    if (!accountOwnerOld)
        accountOwnerOld = [[NSUserDefaults standardUserDefaults] stringForKey:@"accountOwner"];
    return accountOwnerOld;
}
- (void)setAccountOwner:(NSString *)accountOwner {
    accountOwnerOld = accountOwner;
    [[NSUserDefaults standardUserDefaults] setObject:accountOwner forKey:@"accountOwner"];
    accountOld = [self decodeGoogleIDToken:accountOwner];
}

- (NSDictionary*)account {
    if (!accountOld)
        accountOld = [self decodeGoogleIDToken:self.accountOwner];
    return accountOld;
}

- (void)refreshTheAccessCode {
    if (!self.isAuthenticated) return;
    
    [self updateStateWithStep:3 success:0 status:@"Refreshing tokens..."];
    NSMutableURLRequest* req = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://oauth2.googleapis.com/token"]];
    
    NSString* mainBody = [NSString stringWithFormat:@"client_id=%@&grant_type=refresh_token&refresh_token=%@", clientID, [self refreshCode]];
    [req setHTTPBody:[mainBody dataUsingEncoding:NSUTF8StringEncoding]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session
                                  dataTaskWithRequest:req
                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSLog(@"made connection TO REFRESH, continuing!!!");
                                      [self handleTokenNetworkResponseWithData:data error:error isRefresh:YES];
                                  }];
    [task resume];
}

- (NSString*)refreshCode {
    if (![self accountOwner]) {self.isAuthenticated = NO;return nil;}
    
    NSDictionary* refreshKeychain = @{
                                      (NSString*)kSecClass: (NSString*)kSecClassGenericPassword,
                                      (NSString*)kSecAttrAccount: (NSString*)[self accountOwner],
                                      (NSString*)kSecAttrService: @"refresh_token",
                                      (NSString*)kSecReturnData: (id)kCFBooleanTrue,
                                      (NSString*)kSecMatchLimit: (id)kSecMatchLimitOne
                                      };
    CFTypeRef resultData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)(refreshKeychain), &resultData);
    if (status == errSecItemNotFound) {
        self.isAuthenticated = NO;
        return nil;
    }
    
    NSString* string = [[NSString alloc] initWithData:(__bridge_transfer NSData *)resultData encoding:NSUTF8StringEncoding];
    return string;
}

- (void)saveKeychainItem:(NSString *)service value:(NSString *)value genericInfo:(NSDictionary *)genericInfo {
    if (!self.accountOwner) return;
    
    NSDictionary *query = @{
                            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrAccount: self.accountOwner,
                            (__bridge id)kSecAttrService: service
                            };
    
    // Always delete before adding to prevent errSecDuplicateItem (-25299)
    SecItemDelete((__bridge CFDictionaryRef)query);
    
    NSMutableDictionary *newItem = [query mutableCopy];
    newItem[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    if (genericInfo) {
        NSData *genericData = [NSJSONSerialization dataWithJSONObject:genericInfo options:0 error:nil];
        newItem[(__bridge id)kSecAttrGeneric] = genericData;
    }
    
    OSStatus stat = SecItemAdd((__bridge CFDictionaryRef)newItem, NULL);
    if (stat != errSecSuccess) {
        NSLog(@"[GCLoginManager] Error adding to keychain for %@: %d", service, (int)stat);
    }
}

// Updates properties on the main thread so UI elements observing them don't crash
- (void)updateStateWithStep:(int)step success:(int)success status:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.success = success;
        self.status = status;
        self.step = step;
    });
}

- (void)scheduleTokenRefresh {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
    
    if (!self.expiry) return;
    
    NSTimeInterval timeUntilExpiry = [self.expiry timeIntervalSinceNow];
    
    // Refresh 60 seconds *before* the token actually expires to ensure continuity
    NSTimeInterval timerInterval = timeUntilExpiry - 60.0;
    
    if (timerInterval <= 0) {
        [self refreshTheAccessCode];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
                                                                 target:self
                                                               selector:@selector(refreshTheAccessCode)
                                                               userInfo:nil
                                                                repeats:NO];
        });
    }
}

- (void)checkAuthenticationState {
    [self updateStateWithStep:5 success:0 status:@"Restoring session..."];
    
    NSString *refreshToken = [self refreshCode];
    if (!refreshToken) {
        self.isAuthenticated = NO;
        self.accountOwner = nil;
        [self updateStateWithStep:0 success:0 status:@"Not authenticated. Waiting for user."];
        return;
    }
    
    self.isAuthenticated = YES;
    
    NSDictionary *query = @{
                            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrAccount: self.accountOwner ?: @"",
                            (__bridge id)kSecAttrService: @"access_token",
                            (__bridge id)kSecReturnData: @YES,
                            (__bridge id)kSecReturnAttributes: @YES,
                            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
                            };
    
    CFDictionaryRef resultDict = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&resultDict);
    
    if (status == errSecSuccess) {
        NSDictionary *result = (__bridge_transfer NSDictionary *)resultDict;
        NSData *tokenData = result[(__bridge id)kSecValueData];
        self.accessCode = [[NSString alloc] initWithData:tokenData encoding:NSUTF8StringEncoding];
        
        NSData *genericData = result[(__bridge id)kSecAttrGeneric];
        if (genericData) {
            NSDictionary *genericDict = [NSJSONSerialization JSONObjectWithData:genericData options:0 error:nil];
            NSTimeInterval expiresAt = [genericDict[@"expires_at"] doubleValue];
            self.expiry = [NSDate dateWithTimeIntervalSince1970:expiresAt];
            
            NSString *scopesStr = genericDict[@"scopes"];
            self.authorisedScopes = [scopesStr componentsSeparatedByString:@" "];
        }
        [self scheduleTokenRefresh];
        [self updateStateWithStep:4 success:1 status:@"Session restored."];
    } else {
        // We have a refresh token, but no access token. Refresh it immediately.
        [self refreshTheAccessCode];
    }
}

#pragma MARK: web server to handle redirect

- (void)startListeningWithCompletion:(void (^)(NSString *code))completion andError:(NSError**)error {
    [self stopListening]; // Ensure no previous server is running
    
    self.serverSocket = socket(AF_INET, SOCK_STREAM, 0);
    if (self.serverSocket < 0) {
        NSLog(@"Failed to create socket.");
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:-1 userInfo:@{@"reason": @"failed to set up redirect"}];
        return;
    }
    
    // Allow the port to be reused immediately after shutdown
    int reuse = 1;
    setsockopt(self.serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    struct sockaddr_in serverAddr;
    bzero(&serverAddr, sizeof(serverAddr));
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1
    while (true) {
        self.serverPort = 56000 + arc4random_uniform(65535 - 56000 + 1);
        serverAddr.sin_port = htons(self.serverPort); // The specific high-numbered port
        
        if (bind(self.serverSocket, (struct sockaddr *)&serverAddr, sizeof(serverAddr)) < 0) {
            NSLog(@"Failed to bind to port %d. Is it already in use?", self.serverPort);
            close(self.serverSocket);
            continue;
        }
        break;
    }
    
    listen(self.serverSocket, 5);
    
    self.listeningSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, self.serverSocket, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    
    dispatch_source_set_event_handler(self.listeningSource, ^{
        struct sockaddr_in clientAddr;
        socklen_t clientAddrLen = sizeof(clientAddr);
        int clientSocket = accept(self.serverSocket, (struct sockaddr *)&clientAddr, &clientAddrLen);
        
        if (clientSocket >= 0) {
            char buffer[4096];
            ssize_t bytesRead = read(clientSocket, buffer, sizeof(buffer) - 1);
            if (bytesRead > 0) {
                buffer[bytesRead] = '\0';
                NSString *request = [NSString stringWithUTF8String:buffer];
                
                // Split the raw HTTP request into lines to easily grab the first line
                NSArray *requestLines = [request componentsSeparatedByString:@"\r\n"];
                NSString *firstLine = requestLines.firstObject;
                
                // Check if the request is a GET method and targets the /oauthredirect path
                if ([firstLine hasPrefix:@"GET /oauthredirect"]) {
                    NSArray *components = [firstLine componentsSeparatedByString:@" "];
                    NSString *fullURLString = @"";
                    
                    if (components.count >= 2) {
                        NSString *pathAndQuery = components[1];
                        fullURLString = [NSString stringWithFormat:@"http://localhost:%d%@", self.serverPort, pathAndQuery];
                    }
                    
                    const char *httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
                    "<html><body style=\"font-family: sans-serif; text-align: center; padding-top: 50px;\">"
                    "<h2>Authentication Routing...</h2>"
                    "<p>You can close this tab and return to the app.</p>"
                    "<script>window.close();</script>"
                    "</body></html>";
                    
                    write(clientSocket, httpResponse, strlen(httpResponse));
                    close(clientSocket);
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self stopListening];
                        if (completion) completion(fullURLString);
                    });
                    
                } else {
                    const char *badResponse = "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n";
                    write(clientSocket, badResponse, strlen(badResponse));
                    close(clientSocket);
                }
            } else {
                close(clientSocket);
            }
        }
    });
    
    dispatch_resume(self.listeningSource);
    NSLog(@"waiting for oauth to hit the redirect");
}

- (void)stopListening {
    if (self.listeningSource) {
        dispatch_source_cancel(self.listeningSource);
        self.listeningSource = nil;
    }
    if (self.serverSocket > 0) {
        close(self.serverSocket);
        self.serverSocket = 0;
    }
}

- (void)stopAuthFlow {
    [self stopListening];
    [self updateStateWithStep:0 success:-1 status:@"stopped"];
}

- (void)reset {
    [self updateStateWithStep:0 success:0 status:@"Waiting for authentication to occur again..."];
    self.step = 0;
    self.success = 0;
    self.status = @"Waiting for authentication to occur again...";
    NSLog(@"reset");
}

- (NSDictionary *)decodeGoogleIDToken:(NSString *)idToken {
    NSArray *segments = [idToken componentsSeparatedByString:@"."];
    
    if (segments.count != 3) {
        NSLog(@"Invalid JWT structure");
        return nil;
    }
    
    NSString *payloadString = segments[1];
    
    NSString *base64 = [payloadString stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSInteger paddingLength = base64.length % 4;
    if (paddingLength != 0) {
        NSString *padding = [@"" stringByPaddingToLength:(4 - paddingLength) withString:@"=" startingAtIndex:0];
        base64 = [base64 stringByAppendingString:padding];
    }
    NSData *payloadData = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    if (!payloadData) {
        NSLog(@"Failed to decode Base64 string");
        return nil;
    }
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:&error];
    
    if (error) {
        NSLog(@"Failed to parse JSON: %@", error.localizedDescription);
        return nil;
    }
    
    return json;
}

@end
