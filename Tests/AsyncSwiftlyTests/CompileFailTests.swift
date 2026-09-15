//===----------------------------------------------------------------------===//
//
// This source file is part of the async-swiftly open source project
//
// Copyright (c) 2026 Erik Basargin and the async-swiftly project authors
// SPDX-License-Identifier: MIT
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import Subprocess
import Testing

struct CompileFailTests {
    @Test func `Task group is noncopyable`() async throws {
        let fixture = try #require(
            Bundle.module.url(forResource: "NonCopyable", withExtension: "swift", subdirectory: "Fixtures")
        )
        
        // Resources may be beside the test executable or nested in its .xctest bundle.
        let directories = sequence(first: Bundle.module.bundleURL) { directory in
            let parent = directory.deletingLastPathComponent()
            return parent == directory ? nil : parent
        }
        let modulesDirectory = try #require(
            directories.lazy.flatMap { [$0.appending(path: "Modules"), $0] }.first {
                FileManager.default.fileExists(atPath: $0.appending(path: "AsyncSwiftly.swiftmodule").path)
            },
            "Cannot find AsyncSwiftly.swiftmodule above \(Bundle.module.bundleURL.path)",
        )
        
        let result = try await Subprocess.run(
            .name("swiftc"),
            arguments: [
                "-typecheck", "-Xfrontend", "-verify",
                "-I", modulesDirectory.path,
                fixture.path,
            ],
            output: .discarded,
            error: .string(limit: 64 * 1024),
        )
        
        #expect(result.terminationStatus.isSuccess, "\(result.standardError)")
    }
}
