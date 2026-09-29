# async-swiftly

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ferikbasargin%2Fasync-swiftly%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/erikbasargin/async-swiftly)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ferikbasargin%2Fasync-swiftly%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/erikbasargin/async-swiftly)
[![CI](https://github.com/erikbasargin/async-swiftly/actions/workflows/ci.yml/badge.svg)](https://github.com/erikbasargin/async-swiftly/actions/workflows/ci.yml)
[![codecov](https://codecov.io/github/erikbasargin/async-swiftly/graph/badge.svg?token=N8PSU6TVV7)](https://codecov.io/github/erikbasargin/async-swiftly)
[![License](https://img.shields.io/github/license/erikbasargin/async-swiftly.svg)](LICENSE)

Async Swiftly helps make tests of concurrent Swift code more predictable by
reducing the need for arbitrary sleeps and yields in test code.

> [!IMPORTANT]
> async-swiftly is preparing for its first alpha release. Its APIs may change
> in breaking ways.

## Getting started

Until the first release, add the `main` branch as a Swift Package Manager dependency:

```swift
.package(url: "https://github.com/erikbasargin/async-swiftly.git", branch: "main")
```

Add the `AsyncSwiftly` product to your test target. For example, given your
app's `loadProfile()` function and a test HTTP stub:

```swift
import AsyncSwiftly
import Synchronization
import Testing

let loadedProfile = Mutex<Result<Profile, any Error>?>(nil)

try await withTestTaskGroup(timeout: 5) { _, group in
    group.addTask(name: "Load profile") { _ in
        let result = await Result { try await loadProfile() }
        loadedProfile.withLock { $0 = result }
    }
    group.addTask(name: "Stub HTTP response") { _ in
        http.stubResult(Profile.test)
    }
}

let result = try #require(loadedProfile.withLock(\.self))
let profile = try result.get()
#expect(profile == Profile.test)
```

Operations start in registration order. If one pauses while waiting for a
dependency, a later operation can provide it. External dependencies may still
resume tasks at unpredictable times, so the group cannot guarantee every
ordering. A finite timeout throws `TestActor.TimeoutError` and cancels the group.

## Development

Run the test suite with `swift test`. On macOS with Xcode 27 or later, run the
stress-tagged tests with:

```sh
mise run stress
```

Set `STRESS_REPETITIONS` to change the default of 10,000 repetitions, or pass
`--skip-build` to reuse an existing Xcode test build.

## License

Async Swiftly is available under the [MIT license](LICENSE).
