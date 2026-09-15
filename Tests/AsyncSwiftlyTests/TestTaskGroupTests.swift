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

import AsyncSwiftly
import Synchronization
import Testing

struct TestTaskGroupTests {
    
    @Test func `Empty registration completes`() async throws {
        try await withTestTaskGroup { actor, _ in
            #expect(#isolation === actor)
        }
    }
    
    @Test func `Operation inherits group isolation`() async throws {
        try await withTestTaskGroup { actor, group in
            group.addTask { _ in
                #expect(#isolation === actor)
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
    
    @Test func `Synchronous operations are executed in order of enqueueing`() async throws {
        let events = Events<Int>()
        let operations = 0..<100
        
        try await withTestTaskGroup { _, group in
            for id in operations {
                group.addTask { _ in
                    events.append(id)
                }
            }
        }
        
        #expect(events.values == Array(operations))
    }
    
    @Test func `Concurrent operations are executed in order of enqueueing`() async throws {
        let events = Events<Int>()
        
        try await withTestTaskGroup { _, group in
            group.addTask { _ in
                for id in 0..<100 {
                    events.append(id)
                    await Task.yield()
                }
            }
            group.addTask { _ in
                events.append(100)
            }
        }
        
        #expect(events.values == Array(0...100))
    }
    
    @Test func `Group times out and drains remaining operations`() async {
        let events = Events<String>()
        
        await #expect(throws: TestActor.TimeoutError.self) {
            try await withTestTaskGroup(timeout: 0.05) { _, group in
                group.addTask { _ in
                    do {
                        try await Task.sleep(for: .seconds(60))
                        Issue.record("Sleep should have been cancelled")
                    } catch is CancellationError {
                        await Task.yield()
                        events.append("cleanup")
                    } catch {
                        Issue.record(error)
                    }
                }
            }
        }
        
        #expect(events.values == ["cleanup"])
    }
    
    @Test func `Scope cancellation drains remaining operations given timeout is set`() async throws {
        let events = Events<String>()
        let started = AsyncStream.makeStream(of: Void.self)
        defer {
            started.continuation.finish()
        }
        
        let task = Task {
            try await withTestTaskGroup { _, group in
                group.addTask { _ in
                    started.continuation.yield()
                    do {
                        try await Task.sleep(for: .seconds(60))
                    } catch is CancellationError {
                        await Task.yield()
                        events.append("cleanup")
                    } catch {
                        Issue.record(error)
                    }
                }
            }
        }
        
        _ = await started.stream.first(where: { _ in true })
        
        task.cancel()
        
        _ = try await task.value
        
        #expect(events.values == ["cleanup"])
    }
}

private final class Events<Value: Sendable>: Sendable {
    private let state = Mutex<[Value]>([])
    var values: [Value] { state.withLock { $0 } }
    func append(_ value: Value) { state.withLock { $0.append(value) } }
}
