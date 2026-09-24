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

import AsyncWakeup
import Foundation

public actor TestActor {
    
    nonisolated public struct TimeoutError: Error {}
    
    nonisolated private let queue = JobPriorityQueue()
    
    private var executors: [LaneExecutor] = []
    private var laneGroup = LaneGroupMachine<AsyncStream<Never>.Continuation>()
    
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
    
    func makeLane() -> Lane {
        let (releaseStream, releaseContinuation) = AsyncStream.makeStream(
            of: Never.self,
            bufferingPolicy: .bufferingNewest(0),
        )
        let laneID = laneGroup.registerLane(releaseContinuation)
        let gate = Lane(laneID: laneID, gate: releaseStream)
        
        queue.appendLane(laneID)
        let executor = LaneExecutor(
            laneID: laneID,
            queue: queue,
            unownedExecutor: unownedExecutor,
        )
        executors.append(executor)
        
        assert(laneID.index == executors.count - 1)
        
        return gate
    }
    
    func runOperation(
        in lane: consuming ReleasedLane,
        operation: @escaping @Sendable (isolated TestActor) async -> Void,
    ) async {
        let laneID = lane.id
        let executor = executors[laneID.index]
        
        defer {
            laneGroup.finish(laneID)
            queue.signal()
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
                
            case .releaseLane(let gate):
                gate.finish()
                
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
                    laneGroup.releaseNextLane().finish()
                }
            }
        }
    }
}

final class Lane: Sendable {
    private let laneID: LaneID
    private let gate: AsyncStream<Never>
    
    fileprivate init(laneID: LaneID, gate: AsyncStream<Never>) {
        self.laneID = laneID
        self.gate = gate
    }

    func waitUntilReleased() async -> ReleasedLane {
        await withTaskCancellationShield {
            var iterator = gate.makeAsyncIterator()
            await iterator.next()
        }
        return ReleasedLane(id: laneID)
    }
}

struct ReleasedLane: ~Copyable, Sendable {
    fileprivate let id: LaneID

    fileprivate init(id: LaneID) {
        self.id = id
    }
}
