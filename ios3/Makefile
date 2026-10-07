THEOS ?= $(HOME)/theos
SDK := $(THEOS)/sdks/iPhoneOS3.1.3.sdk
ARCHS := armv6 armv7
COMMON_FLAGS := -isysroot $(SDK) -miphoneos-version-min=3.1.3 -fno-objc-arc -fblocks -O2
CORE_FLAGS := -include $(CURDIR)/TGIOS3Foundation.h -I$(CURDIR)/../demo

.PHONY: all clean blocks smoke crypto crypto-smoke
all: $(foreach arch,$(ARCHS),out/$(arch)/libTGIOS3Core.a)

blocks:
	sh build-blocks-runtime.sh

crypto:
	sh build-openssl-armv6.sh armv6
	sh build-openssl-armv6.sh armv7

crypto-smoke: crypto
	@for arch in $(ARCHS); do \
		gcc=""; \
		if [ "$$arch" = armv6 ]; then gcc="$(SDK)/usr/lib/gcc/arm-apple-darwin9/4.2.1/v6/libgcc.a"; fi; \
		xcrun clang -target $$arch-apple-ios3.1.3 -isysroot $(SDK) \
			-miphoneos-version-min=3.1.3 -Iout/openssl-$$arch/install/include \
			crypto-smoke.c out/openssl-$$arch/install/lib/libcrypto.a $$gcc \
			-framework Security -framework CoreFoundation \
			-o out/openssl-$$arch/crypto-smoke || exit 1; \
	done

out/%/TGTL.o: ../demo/TGTL.m TGIOS3Foundation.h
	@mkdir -p $(dir $@)
	xcrun clang -target $*-apple-ios3.1.3 $(COMMON_FLAGS) $(CORE_FLAGS) -c $< -o $@

out/%/TGIOS3Foundation.o: TGIOS3Foundation.m TGIOS3Foundation.h
	@mkdir -p $(dir $@)
	xcrun clang -target $*-apple-ios3.1.3 $(COMMON_FLAGS) $(CORE_FLAGS) -c $< -o $@

out/%/TGIOS3Transport.o: TGIOS3Transport.m TGIOS3Transport.h
	@mkdir -p $(dir $@)
	xcrun clang -target $*-apple-ios3.1.3 $(COMMON_FLAGS) $(CORE_FLAGS) -c $< -o $@

out/%/TGIOS3UnauthenticatedSession.o: TGIOS3UnauthenticatedSession.m TGIOS3UnauthenticatedSession.h TGIOS3Transport.h
	@mkdir -p $(dir $@)
	xcrun clang -target $*-apple-ios3.1.3 $(COMMON_FLAGS) $(CORE_FLAGS) -c $< -o $@

out/%/TGIOS3Handshake.o: TGIOS3Handshake.m TGIOS3Handshake.h TGIOS3UnauthenticatedSession.h
	@mkdir -p $(dir $@)
	xcrun clang -target $*-apple-ios3.1.3 $(COMMON_FLAGS) $(CORE_FLAGS) -c $< -o $@

out/%/TGIOS3PQ.o: TGIOS3PQ.m TGIOS3PQ.h
	@mkdir -p $(dir $@)
	xcrun clang -target $*-apple-ios3.1.3 $(COMMON_FLAGS) $(CORE_FLAGS) -c $< -o $@

out/%/libTGIOS3Core.a: out/%/TGTL.o out/%/TGIOS3Foundation.o out/%/TGIOS3Transport.o out/%/TGIOS3UnauthenticatedSession.o out/%/TGIOS3Handshake.o out/%/TGIOS3PQ.o
	xcrun ar rcs $@ $^

smoke: all blocks
	@for arch in $(ARCHS); do \
		xcrun clang -target $$arch-apple-ios3.1.3 $(COMMON_FLAGS) $(CORE_FLAGS) \
			-framework Foundation -framework UIKit -framework Security \
			smoke.m out/$$arch/libTGIOS3Core.a out/$$arch/libBlocksRuntime.a \
			-o out/$$arch/ios3-smoke || exit 1; \
	done

clean:
	rm -rf out
