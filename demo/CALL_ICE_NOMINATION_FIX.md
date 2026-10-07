# ICE nomination — 0.13.5

The supplied device diagnostic showed outgoing DTLS ClientHello packets with no received DTLS packets, despite working relay STUN traffic and received audio signaling.

The client previously committed to a route at libjuice `connected` (a successful provisional check), then closed competing routes. Selection now waits for `completed` (the nominated pair). Reflector callbacks preserve that distinction; the public connected event is emitted after nomination. Route diagnostics now include nomination and DTLS sent/received counters.

Verification: the host fixture injects a provisional direct connection before relay nomination. Temporary copies with the previous selection logic fail the wrapper UDP case (`caller candidate`). Fixed sources pass standalone UDP/TCP, wrapper UDP/TCP, and blocked UDP with delayed TCP fallback, including DTLS fingerprints, directional keys and bidirectional media. The armv7 package builds successfully.

Actual interoperability with the modern Telegram peer still requires a repeated device call. This regression establishes a route-selection bug, without proving it is the only cause of the reported stall.
