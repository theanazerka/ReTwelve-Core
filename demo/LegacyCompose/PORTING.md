# Telegram 1.1 creation UI port

Source: `/Users/anazerka/Downloads/telegram_iphone.src/` (Telegram for iOS 1.1, Copyright Peter Iakovlev, 2013; GPL v2 or later). License is included in `Resources/OriginalTelegram/LICENSE`.

## Source used by the application

- `TGContactsController.mm`: original contact section model and sorting, table UI, contact cells and section headers, search integration, selection updates, token field callbacks and animation methods. The contact-loading and action dispatch backend is adapted to TGClient.
- `TGSelectContactController.m`: original group-selection controller, Next button, selection callbacks, and transition to the creation form. Existing secret-chat networking is excluded.
- `TGTelegraphConversationProfileController.mm`: the original **create-chat branch**: grouped table, title field header, create button, member cells, grouped backgrounds, title editing and participant updates. Existing-conversation administration branches are excluded. Creation RPCs use TGClient.
- Complete UI dependency implementations copied from Telegram 1.1: TGContactCell, TGContactCellContents, TGUserMenuItemCell, TGGroupedCell, TGTokenFieldView, TGTokenView, TGBackspaceTextField, TGSearchBar, TGSearchDisplayMixin, TGToolbarButton, TGActionTableView, TGProgressWindow, TGDateLabel, TGLabel, TGHighlightTriggerLabel and menu models. TGFlatActionCell is compiled from the application root.

`upstream/` preserves original source files for comparison; those originals are not compiled. The dependencies retain their drawing/layout/animation code, with compatibility imports, namespaced resource paths, modern compiler adjustments, and 64-bit user IDs.

## Adaptation boundary

`TGLegacyUICompat` supplies current user/contact/avatar data, localization, original assets, keyboard inset management and the small subset of the old ActionStage/base-controller API used by this UI. The application keeps its current navigation controller and MTProto implementation.

Channels and supergroups did not exist in Telegram 1.1. Their entries and creation RPCs extend the ported UI; they are not presented as original Telegram 1 functionality. Selecting a contact opens the existing application's conversation controller.

## Verification

The iOS 6 armv7 build compiles and links with the ported UI classes. Live device/navigation/RPC testing remains separate from compilation.

## Channel wizard (0.12.62)

`TGChannelCreationController` implements the supplied modern channel-creation sequence with iOS 6 grouped tables and the ported Telegram toolbar/contact controls: introduction, title/photo/description, visibility/invitation/settings, contact invitations. This channel-specific flow is new application code, since Telegram 1.1 had no channels.

The introduction uses the supplied `SystemTGS/Converted/Channel.gif`, converted to a hardware-decoded H.264 color/opacity video at 60 frames per second, preserving its 3.6-second duration. TGTransparentAnimationView displays the alpha channel and holds the final PNG without looping.

The channel is created once when advancing from the information form. Returning to the form updates that channel instead of creating another. Invite editing keeps the link while changing approval; explicit reset revokes the prior link and generates a new one. Empty contact selection completes without invitations.
