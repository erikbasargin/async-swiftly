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
    
    private enum LaneState {
        case pending(CheckedContinuation<Void, Never>?)
        case active
        case finished
        
        var isFinished: Bool {
            if case .finished = self {
                true
            } else {
                false
            }
        }
    }
    
    nonisolated private let queue = JobPriorityQueue()
    
    private var executors: [OperationExecutor] = []
    private var laneStates: [LaneState] = []
    
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
            await drain()
            
            // User operations are finished; only the watchdog can remain.
            group.cancelAll()
        }
    }
    
    func registerLane() -> Int {
        let bucketId = queue.appendBucket()
        let executor = OperationExecutor(
            id: bucketId,
            queue: queue,
            unownedExecutor: unownedExecutor,
        )
        executors.append(executor)
        laneStates.append(.pending(nil))
        
        assert(bucketId == executors.count - 1)
        
        return bucketId
    }
    
    func runLane(
        id: Int,
        operation: @escaping @Sendable (isolated TestActor) async -> Void,
    ) async {
        let executor = executors[id]
        
        defer {
            laneStates[id] = .finished
        }
        
        if case .pending(let continuation) = laneStates[id] {
            assert(continuation == nil)
            await withCheckedContinuation { continuation in
                laneStates[id] = .pending(continuation)
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
        var nextLaneID = 0
        
        while true {
            if let (bucketIndex, job) = queue.popFirst() {
                assert(bucketIndex <= nextLaneID)
                let executor = executors[bucketIndex]
                job.runSynchronously(
                    isolatedTo: executor.unownedExecutor,
                    taskExecutor: executor.asUnownedTaskExecutor(),
                )
                continue
            }
            
            if laneStates.allSatisfy(\.isFinished) {
                return
            }
            
            guard nextLaneID < laneStates.count else {
                await Task.yield()
                continue
            }
            
            let previousState = nextLaneID == 0 ? nil : laneStates[nextLaneID - 1]
            
            switch previousState {
            case nil, .finished:
                resume(laneID: nextLaneID)
                nextLaneID += 1

            case .active:
                await Task.yield()

            case .pending:
                preconditionFailure("The previous lane must already be released")
            }
        }
    }
    
    private func resume(laneID: Int) {
        guard case .pending(let continuation) = laneStates[laneID] else {
            preconditionFailure("A lane can only be released once")
        }
        laneStates[laneID] = .active
        continuation?.resume()
    }
}
