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

import Testing

@testable import AsyncSwiftly

struct TestJobPriorityQueue {
    
    @Test func `Cancelled caller still detects quiescence`() async throws {
        let queue = JobPriorityQueue()

        let result = try await Task {
            try withUnsafeCurrentTask { currentTask in
                try #require(currentTask).cancel()
            }
            return await queue.wait(detectingQuiescence: true)
        }.value

        #expect(result == .quiescenceDetected)
    }
}
