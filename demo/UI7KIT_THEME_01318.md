# ReTwelve 0.13.18 — emergency launch recovery

0.13.17 enabled UI7Kit's global UIKit backport on the connected iOS 8.4.1 phone. The user reported an indefinite black launch screen after that update. Those patches previously ran only on iOS 6.

- Restored the OS boundary: global UI7Kit patches run only on iOS 6, including when linked against SDK 6. iOS 7+ never receives them.
- A one-time migration on iOS 7+ switches the affected theme preference OFF and records TGThemeRecoveryVersion=118. Account/session data is not changed. Later launches preserve the user's selected value.
- Kept linked SDK 6.0 so classic system controls can render again.
- Added startup stage/main-queue diagnostics for verification on the actual phone.
- Flat styling on iOS 7+ currently uses custom resource adapters; complete flat system controls are not delivered by this recovery.

Verification: armv7 compile, runtime regression test, IPA SDK/version/minimum OS/resources/ZIP validation. Installation succeeded on the connected iPhone 5/iOS 8.4.1; queried installed version 0.13.18/build 118. The device log confirms a new launch at 20:33:01 (OS 8.4.1, flat=0, globalPatch=0), root window visible as TGTabsController at 20:33:02 and the main queue responsive. User visual confirmation is still pending.
