//
//  GCAnnouncementInfoWindowController.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCAnnouncementInfoWindowController.h"
#import "GCImageCache.h"
#import "GCUserProfile.h"

@interface GCAnnouncementInfoWindowController ()

@end

@implementation GCClipView
- (BOOL)isFlipped { return YES; }
@end

@implementation GCAnnouncementInfoWindowController

- (id)initWithAnnouncement:(GCAnnouncement *)announcement {
    self = [super initWithWindowNibName:@"GCAnnouncementInfoWindowController"];
    if (self) {
        _announcement = announcement;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextChanged:)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification object:announcement.managedObjectContext];
    }
    return self;
}


- (void)contextChanged:(NSNotification *)n {
    if ([n.userInfo[NSDeletedObjectsKey] containsObject:self.announcement]) self.announcement = nil;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self resizeWindowToFitText];
    [GCImageCache loadImageFromURL:[NSURL URLWithString:self.announcement.author.photoUrl] completion:^(NSImage* img, NSError* err){
        if (err || !img) {
            self.pfp.image = [NSImage imageNamed:NSImageNameCaution];
        } else {
            self.pfp.image = img;
        }
    }];
}

// what is ts
- (void)resizeWindowToFitText {
    NSWindow *window = self.window;
    NSTextView *textView = self.textView;
    [self.textView setFont:[NSFont systemFontOfSize:12]];
    NSScrollView *scrollView = textView.enclosingScrollView;
    [window.contentView layoutSubtreeIfNeeded];     // make sure the text container has its final width
    
    NSLayoutManager *lm = textView.layoutManager;
    NSTextContainer *tc = textView.textContainer;
    [lm ensureLayoutForTextContainer:tc];
    CGFloat wanted = ceil(NSHeight([lm usedRectForTextContainer:tc])) + textView.textContainerInset.height * 2;
    
    // how much taller (or shorter) the window must become so the scroll view shows all the text
    CGFloat delta = wanted - scrollView.contentSize.height;
    
    NSRect frame = window.frame;
    NSRect visible = (window.screen ?: [NSScreen mainScreen]).visibleFrame;
    
    CGFloat height = frame.size.height + delta;
    height = MIN(height, 500);       // never taller than the screen
    height = MAX(height, window.minSize.height);
    
    NSRect newFrame = frame;
    newFrame.size.height = height;
    newFrame.origin.y = NSMaxY(frame) - height;      // keep the top edge where it is
    if (NSMaxY(newFrame) > NSMaxY(visible)) newFrame.origin.y = NSMaxY(visible) - height;
    if (NSMinY(newFrame) < NSMinY(visible)) newFrame.origin.y = NSMinY(visible);
    
    [self.textView setEditable:NO];
    [window setFrame:newFrame display:YES];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end
