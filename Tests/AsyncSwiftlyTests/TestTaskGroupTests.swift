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

import Synchronization
import AsyncSwiftly
import Testing

struct TestTaskGroupTests {
    
    @Test func `Empty registration completes`() async throws {
        try await withTestTaskGroup { actor, _ in
            #expect(#isolation === actor)
        }
    }
    
    @Test func `Operation inherits group isolation`() async throws {
        await #expect(processExitsWith: .success) {
            try await withTestTaskGroup { actor, group in
                group.addTask { _ in
                    actor.assertIsolated()
                }
            }
        }
    }
    
    @Test func `Operations are skipped if scope is cancelled`() async throws {
        let events = Events<Int>()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await withTestTaskGroup { _, group in
                for id in 0..<10 {
                    group.addTask { _ in
                        events.append(id)
                    }
                }
            }
        }
        try await task.value
        #expect(events.values.isEmpty == true)
    }
}

private final class Events<Value: Sendable>: Sendable {
    private let state = Mutex<[Value]>([])
    var values: [Value] { state.withLock { $0 } }
    func append(_ value: Value) { state.withLock { $0.append(value) } }
}
