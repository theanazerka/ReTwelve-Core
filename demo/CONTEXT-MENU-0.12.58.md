# Message menu, 0.12.58

Replaced the previous menu implementation with one compact action card. The chosen message is captured once at its native display scale, instead of constructing a different bubble and text preview. Long messages/media are clipped to a 96-point preview. The card contains a 42-point reaction strip and 40-point action rows, at most 240 points wide. Paper assets come from the original iOS 6 Telegram resource set; action icons are rasterized from Telegram-iOS Chat/Context Menu PDF assets. The background uses a translucent dimming layer with no live blur or full-screen image processing.

Opening animates the selected message into position with the card fading/scaling into place; closing fades and translates the overlay. Touch highlighting uses the original selected-cell resource. Actions preserve reply, copy, edit, forward, delete and reactions, including the existing delete confirmation. Selection logic and network actions are unchanged.

Verified: iOS 6 armv7 build and 160 placement cases covering 320x480, 320x568, 375x667, 414x896 and 568x320. Device appearance and animation smoothness are unverified.
