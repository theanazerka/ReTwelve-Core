# Blocks Runtime for iPhone OS 3

`Block.h`, `Block_private.h`, `data.c`, and `runtime.c` are from LLVM compiler-rt,
commit `8de4cb45931adab063265b565408ff2b72be668d`, directory
`compiler-rt/lib/BlocksRuntime`. Their Apple copyright and permissive license
are included in each source file. `config.h` supplies the feature definitions
for the iPhone OS 3.1.3 SDK.

This runtime only supplies Blocks symbols absent from iPhone OS 3. It does not
provide Grand Central Dispatch.
