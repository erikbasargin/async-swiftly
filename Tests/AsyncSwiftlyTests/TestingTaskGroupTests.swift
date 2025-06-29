//
//  TestingTaskGroupTests.swift
//  async-swiftly
//
//  Created by Erik Basargin on 25/06/2025.
//

import AsyncSwiftly
import Testing
import TestingSupport

struct TestingTaskGroupTests {

    @Test("Given tasks are scheduled at the same time, Then all the tasks are executed in order of enqueueing")
    func executeTasksInOrderOfEnqueueing() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        let operations = 0..<100
        
        try await withTestingTaskGroup { group in
            for operation in operations {
                group.addTask(at: 0) {
                    continuation.yield(operation)
                }
            }
        }
        
        continuation.finish()
        
        await #expect(stream.collect() == Array(operations))
    }
    
    @Test("Given tasks are scheduled at different times, Then all the tasks are executed in order of scheduling")
    func executeTasksInOrderOfScheduling() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        let source = 0..<100
        
        try await withTestingTaskGroup { group in
            for (time, operation) in zip(source, source).reversed() {
                group.addTask(at: time) {
                    continuation.yield(operation)
                }
            }
        }
        
        continuation.finish()
        
        await #expect(stream.collect() == Array(source))
    }
    
    @Test("Given tasks with large time gaps, Then all the tasks are executed in order of scheduling")
    func executeTasksWithLargeTimeGaps() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        
        try await withTestingTaskGroup { group in
            group.addTask(at: 10) {
                continuation.yield(1)
            }
            group.addTask(at: 20) {
                continuation.yield(2)
            }
            group.addTask(at: 50) {
                continuation.yield(3)
            }
        }
        
        continuation.finish()
        
        await #expect(stream.collect() == [1, 2, 3])
    }
    @Test("Given task suspended by dependency, When another task resolves dependency, Then dependent task resumes its work")
    func resumeDependentTaskWhenDependencyIsResolved() async throws {
        let order = AsyncStream.makeStream(of: Int.self)
        let dependency = AsyncStream.makeStream(of: Void.self)
        
        try await withTestingTaskGroup { group in
            group.addTask(at: 0) {
                order.continuation.yield(0)
                _ = await dependency.stream.prefix(1).collect()
                order.continuation.yield(3)
            }
            group.addTask(at: 1) {
                order.continuation.yield(1)
                dependency.continuation.yield()
                order.continuation.yield(2)
            }
        }
        
        order.continuation.finish()
        dependency.continuation.finish()
        
        await #expect(order.stream.collect() == [0, 1, 2, 3])
    }
    
    @Test("Given task suspended by long running dependency, When group exceeds provided timeout, Then group is cancelled and throws timeout error")
    func cancelTaskGroupWhenProvidedTimeoutIsExceeded() async throws {
        await #expect(throws: TimeoutError.self) {
            try await withTestingTaskGroup(timeout: 1) { group in
                group.addTask(at: 0) {
                    // Cannot use #expect(throws: CancellationError.self) 🥲
                    // Error: Recursive expansion of macro 'expect(throws:_:sourceLocation:performing:)'
                    //
                    // await #expect(throws: TimeoutError.self) {
                    //     try await Task.sleep(for: .seconds(5))
                    // }
                    
                    await confirmation { longRunningTaskIsCancelled in
                        do {
                            try await Task.sleep(for: .seconds(5))
                        } catch is CancellationError {
                            longRunningTaskIsCancelled()
                        } catch {
                            Issue.record(error)
                        }
                    }
                }
            }
        }
    }
}
