# Audio calls on iOS 6

Current implementation:

- `TGClient` receives `updatePhoneCall` from its main MTProto session and posts `TGClientPhoneCallNotification`.
- `prepareCallKey:` requests `messages.getDhConfig` and creates an ephemeral, validated DH exchange off the UI thread.
- `TGCallCrypto` computes the public value, SHA-256 commitment, 256-byte shared key and Telegram key fingerprint. It rejects invalid primes, weak public values, mismatched commitments and fingerprints.
- `TGClient` serializes `phone.requestCall`, `phone.acceptCall`, `phone.confirmCall`, `phone.receivedCall`, `phone.discardCall` and `phone.sendSignalingData`. The call coordinator advertises media protocol 7.0.0.
- `TGCallAudio` builds for armv7/iOS 6 and handles duplex microphone/speaker audio, buffering and 20 ms Opus packets. Full audio operation still needs device testing.
- `TGCallCipher` implements signaling encryption with Telegram's call-key derivation, AES-256-CTR and a 64-packet replay window. A host-side test checks both directions, tampering and replay rejection. Media uses DTLS-SRTP separately.
- `TGCallICE` wraps a native armv7 build of libjuice to gather ICE candidates and use Telegram's WebRTC STUN/TURN endpoints. It also selects native Telegram Reflector routes through `TGCallReflector`. The vendored library is MPL 2.0; see `call-transport/src/libjuice/LICENSE`.
- `TGCallSignal` serializes and validates the initial setup, ICE candidates, and audio-only Opus channel negotiation for tgcalls protocol 7.0.0.
- `TGCallDTLS` verifies the authenticated remote certificate fingerprint and derives directional SRTP keys. A host-side two-peer handshake test passes.
- `TGCallRTP` uses an armv7 build of libSRTP 2.6.0 to protect and receive Opus RTP packets. A host-side two-peer test passes, including replay and tamper rejection. The vendored library uses the three-clause BSD license; see `call-transport/src/libsrtp/LICENSE`.
- `TGCallMedia` connects ICE, DTLS, SRTP, Opus and the iOS 6 audio unit. `TGCallCoordinator` handles incoming and outgoing Telegram call updates and presents a basic call screen. One-to-one calls can now be initiated from a private chat.

This is an **experimental** implementation. Device tests have confirmed signaling exchange, but successful audio with modern Telegram has not yet been confirmed. A build and isolated crypto/media tests do not prove live call interoperability or audio quality.

## Reflector transport (0.9.8)

The previous implementation ignored classic `phoneConnection` endpoints, although modern Telegram uses them for media Reflector routes. libjuice accepted the text of a `.reflector` candidate without resolving its synthetic hostname; that made `R:2/2` misleading. Reflector candidates now go through the dedicated transport and are rejected if there is no matching configured server ID/port.

`TGCallReflectorProtocol` implements the sorted classic ID mapping, 12-byte peer-tag prefix, little-endian local/remote tags, big-endian datagram length, padding and registration packet. `TGCallReflector` supports UDP and TCP (0xeeeeeeee prologue, little-endian frame lengths, partial reads/writes). It only uses endpoints supplied in the call; no external helper process is needed on the device.

ICE remains handled by libjuice: a small local extension (`juice_config_t.cb_send` and `juice_input_packet`) allows its checked datagrams to travel inside Reflector packets. Each remote tag gets a check context with the signaled ICE credentials, caller/callee role, HMAC validation, nomination and consent checks. These contexts bind to loopback and send through the application callback. The wire advertises only the actual Reflector candidate. The first working route carries DTLS and SRTP; other Reflector sockets are stopped. Socket errors, input sizes, candidate counts and TCP backlogs are bounded.

Protocol sources are modern code, not the 2013 UI archive:

- TelegramMessenger/tgcalls commit `efd330ca04f74706024a5abdfb5b41f4e4dd1065`: `tgcalls/v2/ReflectorPort.cpp` and `RawTcpSocket.cpp`.
- TelegramMessenger/Telegram-iOS commit `6ad963e5b62d354da79040f388ae2b9132fb17b8`: `submodules/TelegramVoip/Sources/OngoingCallContext.swift` (sorted reflector ID mapping).

`tests/TGCallReflectorTest.m` and `tests/reflector_server_test.py` exercise UDP and TCP, fragmented TCP headers, invalid peer prefixes/lengths/tags, ICE role negotiation, real DTLS fingerprint verification, directional SRTP key agreement, packet round trips, integration with `TGCallICE` selection, and stopping. They use a local fixture, no Telegram account. Host runs use AddressSanitizer. Live Telegram reflector access and iPhone microphone/speaker operation still require a device test.

Before declaring calls reliable, the remaining checks are:

1. Test outgoing and incoming calls on real devices and capture the exact on-screen error and call logs for failed handshakes. Telegram clients may select a protocol or transport variant that this minimal media engine cannot yet handle.
2. Add RTP jitter buffering, packet-loss concealment, RTCP, audio interruption handling, speaker/mute controls, and timeouts. These are needed for call quality and resilience.
3. Audit media-thread synchronization and test repeated calls, cancellation and background operation on iOS 6 hardware.

Protocol references: [current call key exchange](https://core.telegram.org/api/end-to-end/video-calls), [older voice-call transport](https://core.telegram.org/api/end-to-end/voice-calls), [security checks](https://core.telegram.org/mtproto/security_guidelines).

## 0.9.9: диагностика реального устройства

Причина таймаута с современным клиентом пока не установлена. Добавлены счётчики фактически отправленных/полученных байтов reflector-сокетов, пакетов с правильным префиксом, ICE-пакетов, готовых/остановленных портов и последней ошибки BSD-сокета. Экран обновляется раз в секунду до соединения. Счётчики не содержат адресов, ключей или учётных данных. В sockaddr явно заполнены sin_len/sin6_len для Darwin; это исправление заполнения структуры, не подтверждённая причина таймаута.

Для следующего исследования нужен весь экран спустя 10 секунд поиска: Relay bytes, valid, Ports, stop, ICE, E вместе с существующими счётчиками. Нули S/T сами по себе не определяют причину. Локальная проверка UDP/TCP не заменяет звонок с современным Telegram на реальном устройстве.

## 0.9.10: резервная попытка TCP

На устройстве 0.9.9: сигнализация 4/4 и 5/5/5, relay 1580 байт отправлено и 0 принято, 0/2 порта готовы, один остановлен с EHOSTUNREACH (65). Отключение VPN, по сообщению пользователя, результат не изменило. Агрегированная ошибка не доказывает отсутствие маршрута у обоих адресов.

Для каждого UDP-reflector создаётся отложенная на 3 секунды TCP-попытка на том же IP и порту, с тем же serverId и отдельным локальным тегом. Адреса или порты не подменяются. UDP продолжает работать до выбора успешного пути. Если ICE уже соединён или звонок завершён, резервная попытка не запускается. Это проба доступности TCP, а не гарантия, что конкретный Telegram endpoint его обслуживает. Пока сокет резервного пути не запущен, удалённые кандидаты сохраняются без расходования ICE-попыток.

Диагностика раздельная по U4/U6/T4/T6: реальные байты, валидные ответы, errno, число остановленных портов. Локальный тест теперь намеренно отбрасывает все UDP-пакеты: клиент без пригодного явно выданного TCP-адреса должен пройти ICE/DTLS и обмен данными через отложенный TCP-путь. Пять сценариев прошли с AddressSanitizer. Живой звонок с современным Telegram всё ещё требует подтверждения на устройстве.

## 0.9.11: media sockets on the iOS VPN interface

The iPhone RVI trace during a failed call sent UDP from the Wi-Fi address to the public voice servers without receiving a reply. A separate, successful desktop Telegram call log selected a UDP relay pair on a VPN `utun` interface. A working modern-to-desktop call on the same Wi-Fi disproved the earlier blanket conclusion that the Wi-Fi cannot carry Telegram calls. These observations support a route mismatch, but do not yet prove the iOS VPN accepts UDP or that the server will answer this specific call.

The native IPv4 reflector sockets now bind to an active point-to-point `utun`, `ppp`, or `ipsec` interface using Darwin `IP_BOUND_IF` when available. If there is no such interface or the option fails, the existing route remains. The main ICE socket remains on its normal route so direct Wi-Fi ICE remains available. Diagnostics append `*` to `U4` or `T4` when the socket bind succeeds. The host reflector fixture has no iOS VPN, so the five existing UDP/TCP and blocked-UDP tests still pass; the iOS VPN route needs a device call to verify.
