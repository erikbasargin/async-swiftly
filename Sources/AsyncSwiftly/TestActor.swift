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
    
    private typealias StateMachine = LaneGroupMachine<AsyncStream<Never>.Continuation>
    
    nonisolated public struct TimeoutError: Error {}
    
    nonisolated private let queue = JobPriorityQueue()
    
    private var laneGroupMachine = StateMachine()
    
    func run(
        timeout seconds: TimeInterval,
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
            
            await drain()
            
            // User operations are finished; only the watchdog can remain.
            group.cancelAll()
        }
    }
    
    func makeLane() -> Lane {
        let (releaseStream, releaseContinuation) = AsyncStream.makeStream(
            of: Never.self,
            bufferingPolicy: .bufferingNewest(0),
        )
        let laneID = laneGroupMachine.registerLane(releaseContinuation)
        let gate = Lane(laneID: laneID, gate: releaseStream)
        
        queue.appendLane(laneID)
        
        return gate
    }
    
    func runOperation(
        id laneID: LaneID,
        operation: @escaping @Sendable (isolated TestActor) async -> Void,
    ) async {
        defer {
            laneGroupMachine.finish(laneID)
            queue.signal()
        }
        
        guard Task.isCancelled == false else {
            return
        }
        
        let executor = LaneExecutor(
            laneID: laneID,
            queue: queue,
            unownedExecutor: unownedExecutor,
        )
        
        await withTaskExecutorPreference(executor) {
            await operation(self)
        }
    }
    
    private func drain() async {
        while true {
            if let (laneID, job) = queue.popFirst() {
                assert(laneGroupMachine.isReleased(laneID))
                job.runSynchronously(isolatedTo: unownedExecutor)
                continue
            }
            
            var effect = laneGroupMachine.reduce(.stalled)
            
            while let currentEffect = effect {
                switch currentEffect {
                case .releaseLane(let gate):
                    gate.finish()
                    effect = nil

                case .suspend(let detectingQuiescence):
                    let action = await waitForResume(detectingQuiescence)
                    effect = laneGroupMachine.reduce(action)

                case .complete:
                    return
                }
            }
        }
    }
    
    private func waitForResume(_ detectingQuiescence: Bool) async -> StateMachine.DrainAction {
        await withTaskCancellationShield {
            await withTaskGroup { [queue] group in
                group.addTask {
                    await queue.wait()
                    return StateMachine.DrainAction.resumed
                }
                if detectingQuiescence {
                    group.addTask {
                        for _ in 0..<1000 {
                            if Task.isCancelled { return .resumed }
                            await Task.yield()
                        }
                        return .quiescenceDetected
                    }
                }
                
                let result = await group.next()!
                group.cancelAll()
                return result
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
    
    func waitUntilReleased() async -> LaneID {
        await withTaskCancellationShield {
            var iterator = gate.makeAsyncIterator()
            await iterator.next()
        }
        return laneID
    }
}
