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

public actor TestActor {
    
    nonisolated public struct TimeoutError: Error {}
    
    nonisolated private let queue = JobPriorityQueue()
    
    private var executors: [OperationExecutor] = []
    private var laneGroup = LaneGroupMachine<CheckedContinuation<Void, Never>>()
    
    func run(
        timeout seconds: TimeInterval = 5,
        body: @Sendable (isolated TestActor, inout TestTaskGroup) -> Void,
    ) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            var testGroup = TestTaskGroup(testActor: self, base: group)
            if seconds.isFinite {
                group.addTask {
                    do {
                        try await Task.sleep(for: .seconds(seconds))
                    } catch is CancellationError {
                        return
                    }
                    
                    throw TimeoutError()
                }
            }
            body(self, &testGroup)
            
            await withTaskCancellationShield {
                await drain()
            }
            
            // User operations are finished; only the watchdog can remain.
            group.cancelAll()
        }
    }
    
    func registerLane() -> LaneID {
        let laneID = laneGroup.registerLane()
        queue.appendLane(laneID)
        let executor = OperationExecutor(
            laneID: laneID,
            queue: queue,
            unownedExecutor: unownedExecutor,
        )
        executors.append(executor)
        
        assert(laneID.index == executors.count - 1)
        
        return laneID
    }
    
    func runLane(
        _ laneID: LaneID,
        operation: @escaping @Sendable (isolated TestActor) async -> Void,
    ) async {
        let executor = executors[laneID.index]
        
        defer {
            laneGroup.finish(laneID)
            queue.signal()
        }
        
        if laneGroup.isPending(laneID) {
            await withCheckedContinuation { continuation in
                laneGroup.wait(laneID: laneID, waiter: continuation)
            }
        }
        
        guard Task.isCancelled == false else {
            return
        }
        
        await withTaskExecutorPreference(executor) {
            await operation(self)
        }
    }
    
    private func drain() async {
        while true {
            if let (laneID, job) = queue.popFirst() {
                assert(laneGroup.isReleased(laneID))
                let executor = executors[laneID.index]
                job.runSynchronously(
                    isolatedTo: executor.unownedExecutor,
                    taskExecutor: executor.asUnownedTaskExecutor(),
                )
                continue
            }
            
            switch laneGroup.nextDrainAction() {
            case .complete:
                return
            case .wait:
                await queue.wait()
            case .resume(let continuation):
                continuation?.resume()
            case .detectBlock:
                let blockDetected = await withTaskGroup { [queue] group in
                    group.addTask {
                        await queue.wait() == .resumed
                    }
                    group.addTask {
                        for _ in 0..<1000 {
                            if Task.isCancelled { return false }
                            await Task.yield()
                        }
                        return true
                    }
                    
                    let result = await group.next()!
                    group.cancelAll()
                    return result
                }
                
                if blockDetected {
                    laneGroup.releaseNextLane()?.resume()
                }
            }
        }
    }
}
