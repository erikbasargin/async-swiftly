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
    
    @Test @MainActor func `Probe expiry detects activity when a queued job outlives its wakeup`() async {
        let queue = JobPriorityQueue(detector: ImmediateQuiescenceDetector())
        let laneID = LaneID(index: 0)
        queue.appendLane(laneID)
        let executor = LaneExecutor(
            laneID: laneID,
            queue: queue,
            unownedExecutor: MainActor.shared.unownedExecutor,
        )
        let task = Task.detached(executorPreference: executor) {}
        defer {
            while let (_, job) = queue.popFirst() {
                job.runSynchronously(isolatedTo: MainActor.shared.unownedExecutor)
            }
            await task.value
        }
        
        // Consume the enqueue signal without removing its job.
        let firstResult = await queue.wait(detectingQuiescence: false)
        #expect(firstResult == .activityDetected)
        #expect(queue.isEmpty == false)
        
        // No signal remains, so only detector expiry can complete this wait.
        let secondResult = await queue.wait(detectingQuiescence: true)
        #expect(secondResult == .activityDetected)
        #expect(queue.isEmpty == false)
    }
}

private struct ImmediateQuiescenceDetector: QuiescenceDetector {
    func waitForExpiry() async throws {}
}
