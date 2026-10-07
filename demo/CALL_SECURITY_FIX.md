# Call security stage — 0.13.4

Reported case: an outgoing call from this client reaches “Защита соединения”, while the modern peer remains at “Соединение”. ICE connectivity alone does not establish that DTLS or audio negotiation has succeeded.

Changes:

- Honor authenticated remote fingerprint `setup`: active peer means local DTLS server, passive peer means client, actpass uses the caller/callee default. This follows the user's modern Telegram `v2/NativeNetworkingImpl.cpp` role selection. SRTP directional keys now use the negotiated TLS role.
- Buffer up to 16 early DTLS datagrams until authenticated peer parameters and the ICE connection are ready, rather than driving a handshake before the peer fingerprint is available.
- Force a 1200-byte DTLS MTU without querying the stream memory BIO. Read SSL errors immediately after the handshake operation.
- Report DTLS role, packet counters, OpenSSL handshake state, remote audio-channel availability and signaling counters after ICE connects. No key material or credentials are logged.
- End an unfinished DTLS handshake with an explicit diagnostic after 25 seconds.

`tests/TGCallDTLSTest.m` passes host checks for ordinary and reversed negotiated roles, early packets, a lost ClientHello/retransmission, certificate fingerprint rejection, and matching directional SRTP keys. The iOS build also compiles against the bundled OpenSSL dependency. These tests do not establish interoperability with the user's modern Telegram; that still requires a repeated device call and its diagnostic output.
