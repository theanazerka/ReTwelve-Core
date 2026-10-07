# iPhone OS 3 port

Target: iPhone OS 3.1.3, armv6 for the original iPhone and iPhone 3G, and
armv7 for iPhone 3GS. This is a separate build path; `demo/` remains the
iOS 6 client.

SDK: `$(THEOS)/sdks/iPhoneOS3.1.3.sdk`. The SDK archive used during setup is
`Sn0wCooder/theos-sdks/iPhoneOS3.1.3.sdk.tbz2`, SHA-256
`7ccc15923bc9be1a4bd234a41bac38f3fea088f1d83a3b18163b4251dccaedd5`.

Run `make -C ios3 smoke` from the repository root. It builds a TL parser, the
Foundation compatibility methods, a blocking MTProto abridged TCP transport,
the first `req_pq_multi` / `resPQ` exchange, `pq` factorization, and Blocks Runtime for both
architectures. The linked smoke executables are under `ios3/out/`.

Run `make -C ios3 crypto-smoke` to build the bundled OpenSSL 1.1.1d crypto
library for armv6 and armv7, targeting iPhone OS 3.1.3. It also links a small
SHA/AES/BIGNUM check against both builds. An armv6 client linking this library
must include the SDK's `usr/lib/gcc/arm-apple-darwin9/4.2.1/v6/libgcc.a` to
provide compiler arithmetic helpers missing from modern Xcode's armv6 runtime.

Run `make -C ios3/probe-app FINALPACKAGE=1 package` to build a separate iPhone
OS 3 test app. Its `.deb` is under `ios3/probe-app/packages/`. The app checks
the first live MTProto exchange, factors `pq`, and reports the result on screen. It does not
ask for a phone number or log in.

The transport is blocking and belongs on a dedicated worker thread. It
implements framing and validates `resPQ`. Authentication, encryption, and
Telegram requests are not connected yet. The existing MtProtoKit relies on
`libdispatch`, which iPhone OS 3 does not provide. This target must use a
separate event loop or a replacement for that dependency. Calls are excluded
from this port.
