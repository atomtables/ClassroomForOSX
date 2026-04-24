//
//  GCProfileViewController.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 21/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCProfileViewController.h"
#import "GCLoginManager.h"

@interface GCProfileViewController ()

@property (nonatomic, readonly) NSString* buttonTitle;

@end

@implementation GCProfileViewController {
    BOOL bindedToStep;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[GCLoginManager main] addObserver:self
                                forKeyPath:@"isAuthenticated"
                                   options:(NSKeyValueObservingOptionNew)
                                   context:nil];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    [self updateUIWithAuthenticationState:@{}];
}

- (void)dealloc {
    [[GCLoginManager main] removeObserver:self forKeyPath:@"isAuthenticated"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    // Check both the object type and the specific keyPath
    if ([object isKindOfClass:[GCLoginManager class]]) {
        if ([keyPath isEqualToString:@"isAuthenticated"]) [self updateUIWithAuthenticationState:change];
        if ([keyPath isEqualToString:@"step"]) [self updateSheetUI];
    }
}

- (void)updateUIWithAuthenticationState:(NSDictionary *)change {
    NSLog(@"%@ %ld", change, (long)[change[NSKeyValueChangeNewKey] boolValue]);
    BOOL authenticated = change[NSKeyValueChangeNewKey] ? [change[NSKeyValueChangeNewKey] boolValue] : [[GCLoginManager main] isAuthenticated];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!authenticated) {
            [self.logInOutButton setTitle:@"Log In"];
            [self.name setStringValue:@"Not logged in"];
            [self.email setStringValue:@""];
        } else {
            [self.logInOutButton setTitle:@"Log Out"];
            [self.name setStringValue:[[GCLoginManager main] account][@"name"] ?: @"Unknown"];
            [self.email setStringValue:[[GCLoginManager main] account][@"email"] ?: @"Unknown again"];
            NSURLSessionTask* task = [[NSURLSession sharedSession] dataTaskWithURL:[[NSURL alloc] initWithString:[[GCLoginManager main] account][@"picture"] ?: @"http://255.255.255.0:5555"] completionHandler:^(NSData* data, NSURLResponse* _, NSError* err) {
                NSLog(@"resp: %@, err: %@", _, err);
                if (err) {
                    NSLog(@"error loading image: %@", err);
                    [self.pfp setImage:[NSImage imageNamed:NSImageNameCaution]];
                    return;
                }
                if (data) {
                    NSImage* image = [[NSImage alloc] initWithData:data];
                    if (image) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.pfp setImage:image];
                        });
                    }
                }
            }];
            [task resume];
        }
    });
}

- (void)updateSheetUI {
    int step = [[GCLoginManager main] step];
    NSString* status = [[GCLoginManager main] status];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logInStatusIndicator setStringValue:[NSString stringWithFormat:@"Step %d/5: %@", step, status]];
    });
    if (step == 0) {
        int success = [[GCLoginManager main] success];
        if (success != 0) {
            @try {
                [self endSheet:nil];
            } @catch (NSError* e) {
                NSLog(@"error occured while removing observer (probably just already removed?): %@", e);
            }
            if (success < 0) {
                NSAlert* alert = [NSAlert alertWithMessageText:@"Failed to authenticate" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Classroom failed to authenticate with Google. %@", status];
                [alert setAlertStyle:NSCriticalAlertStyle];
                [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse resp){
                    NSLog(@"resp:%ld", (long)resp);
                    
                }];
            }
        }
    }
}

- (IBAction)attemptToLogOut:(NSButton*)sender {
    [[GCLoginManager main] reset];
    [self.logInStatusIndicator setStringValue:[NSString stringWithFormat:@"Step %d/5: %@", [[GCLoginManager main] step], [[GCLoginManager main] status]]];
    [self.view.window beginSheet:self.logInSheetForShowingProgress completionHandler:^(NSModalResponse returnCode) {
        [self.pi stopAnimation:nil];
        @try {
            if (bindedToStep) {
                [[GCLoginManager main] removeObserver:self forKeyPath:@"step"];
                bindedToStep = NO;
            }
            NSTimer* timer = [NSTimer timerWithTimeInterval:1 target:[GCLoginManager main] selector:@selector(reset) userInfo:nil repeats:NO];
            [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        } @catch (NSError* e) {
            NSLog(@"an error occured removing the observer from step. most likely it was already removed: %@", e);
        }
    }];
    [self.pi startAnimation:nil];
    
    if (!bindedToStep) {
        [[GCLoginManager main] addObserver:self
                                forKeyPath:@"step"
                                   options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                                   context:nil];
        bindedToStep = YES;
    }
    
    
    [[GCLoginManager main] runRedirectUri];
}

- (IBAction)endSheet:(NSButton*)sender {
    [[GCLoginManager main] stopAuthFlow];
    [self.view.window endSheet:self.logInSheetForShowingProgress];
}

@end
