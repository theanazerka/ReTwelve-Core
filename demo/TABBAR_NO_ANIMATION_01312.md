# Tab bar transitions — 0.13.12

Removed the explicit 0.25-second UIView animation around tab bar and content container layout. Updates temporarily disable UIView animations and Core Animation actions, preserve the caller's animation state and remove existing animations from the tab bar layer. This also suppresses inherited animation blocks during navigation. Player visibility requests now pass animated:NO. Navigation push/pop and the expanded player retain their own transitions.

Validation: armv7 package compilation and IPA integrity/version checks. Physical behavior still requires observing navigation on the device.
