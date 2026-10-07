#pragma once

// iOS 6 has no os_unfair_lock. This compatibility shim maps the zero-initialized
// lock used by MtProtoKit to the lock available on iOS 6.
#include <libkern/OSAtomic.h>

typedef OSSpinLock os_unfair_lock;
#define OS_UNFAIR_LOCK_INIT OS_SPINLOCK_INIT
#define os_unfair_lock_lock(lock) OSSpinLockLock((lock))
#define os_unfair_lock_unlock(lock) OSSpinLockUnlock((lock))
