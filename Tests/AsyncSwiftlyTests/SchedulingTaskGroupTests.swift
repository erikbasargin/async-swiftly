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
        
        let group = SchedulingTaskGroup()
        
        for operation in operations {
            group.addTask(at: 0) {
                continuation.yield(operation)
            }
        }
        
        await group.start()
        
        continuation.finish()
        
        await #expect(stream.collect() == Array(operations))
    }
}
