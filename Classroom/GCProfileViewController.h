//
//  GCProfileViewController.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 21/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GCProfileViewController : NSViewController

@property (nonatomic, weak) IBOutlet NSImageView* pfp;
@property (nonatomic, weak) IBOutlet NSTextField* name;
@property (nonatomic, weak) IBOutlet NSTextField* email;

@property (nonatomic, weak) IBOutlet NSButton* logInOutButton;

@property (nonatomic, weak) IBOutlet NSWindow* logInSheetForShowingProgress;
@property (nonatomic, weak) IBOutlet NSTextField* logInStatusIndicator;
@property (nonatomic, weak) IBOutlet NSProgressIndicator* pi;

@end
