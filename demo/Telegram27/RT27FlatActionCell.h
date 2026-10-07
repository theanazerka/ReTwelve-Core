#import "../Seven/RT7UIKit.h"
#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef enum {
    RT27FlatActionCellModeInvite = 0,
    RT27FlatActionCellModeCreateGroup = 1,
    RT27FlatActionCellModeCreateEncrypted = 2,
    RT27FlatActionCellModeCreateGroupContacts = 3,
    RT27FlatActionCellModeBroadcasts = 4,
    RT27FlatActionCellModeCreateBroadcast = 5,
} RT27FlatActionCellMode;

@interface RT27FlatActionCell : RT7ListCell

- (void)setMode:(RT27FlatActionCellMode)mode;

@end
