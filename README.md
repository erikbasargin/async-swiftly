AsyncSwiftly helps make Swift concurrency tests more predictable.

> [!IMPORTANT]
> This project is in early development and is currently incomplete. Features, APIs, and behavior are subject to change without notice.

## Stress testing

On macOS with Xcode 27 or later, run:

```sh
mise run stress
```

This builds the tests and runs every test tagged `.stress` 10,000 times, continuing
after assertion failures. Tests repeat in the same process, with Xcode's default
and maximum test execution allowances set to 5 seconds. Tagged tests also run
once as part of the normal test suite.

Override the repetition count or reuse an existing Xcode test build:

```sh
STRESS_REPETITIONS=100 mise run stress
mise run stress --skip-build
```

Each run prints its unique result bundle path under `.build/stress/`.
