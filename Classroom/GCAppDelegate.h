//
//  GCAppDelegate.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 30/03/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GCAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (IBAction)saveAction:(id)sender;

@end
