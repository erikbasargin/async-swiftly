//
//  SchedulingTaskGroupTests.swift
//  async-swiftly
//
//  Created by Erik Basargin on 25/06/2025.
//

import AsyncSwiftly
import Testing
import TestingSupport

struct SchedulingTaskGroupTests {

    @Test("Given tasks are scheduled at the same time, Then all the tasks are executed in order of enqueueing")
    func executeTasksInOrderOfEnqueueing() async throws {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let operations = 0..<5
        
        try await withSchedulingTaskGroup { group in
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
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let source = 0..<5
        
        try await withSchedulingTaskGroup { group in
            for (time, operation) in zip(source, source).reversed() {
                group.addTask(at: time) {
                    continuation.yield(operation)
                }
            }
        }
        
        continuation.finish()
        
        await #expect(stream.collect() == Array(source))
    }
}
