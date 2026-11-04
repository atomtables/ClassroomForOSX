//
//  GCAnnouncementInfoWindowController.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCAnnouncement.h"

@interface GCClipView: NSClipView
@end

@interface GCAnnouncementInfoWindowController : NSWindowController

- (id)initWithAnnouncement:(GCAnnouncement *)announcement;
@property (nonatomic) GCAnnouncement* announcement;
@property (unsafe_unretained) IBOutlet NSTextView* textView;
@property (weak) IBOutlet NSImageView* pfp;


@end
