# Chat opening crash, 0.14.2

The on-device exception recorded by 0.14.1 identified:

    NSInvalidArgumentException
    -[UIImageView setTextColor:]: unrecognized selector
    -[TGHistoryController viewWillAppear:]

The chat controller accessed titleControl.subviews[0] and [1] as UILabels.
FlatUIKit FUIButton creates its own background UIImageView, invalidating this
assumption. The controller now retains headerTitleLabel and subtitleLabel and
styles them directly. Other compiled application sources were searched for
positional subview access; no equivalent occurrence was found outside this
site (uncompiled old UI7Kit and upstream reference sources excluded).

0.14.1's navigation ownership changes remain in place, but were not the fix
for this exception. The exception handler remains available for later faults.
