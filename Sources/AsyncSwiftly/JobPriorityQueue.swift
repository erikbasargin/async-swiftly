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
import BucketPriorityQueue
import Synchronization

final class JobPriorityQueue: Sendable {
    
    enum WaitResult: Sendable {
        case activityDetected
        case quiescenceDetected
    }
    
    private let wakeup = AsyncWakeup()
    private let queue = Mutex(BucketPriorityQueue<QueuedJob>())
    
    var isEmpty: Bool {
        queue.withLock(\.isEmpty)
    }
    
    func appendLane(_ laneID: LaneID) {
        queue.withLock { queue in
            let bucketIndex = queue.appendBucket()
            assert(bucketIndex == laneID.index)
        }
    }
    
    func append(_ element: QueuedJob, to laneID: LaneID) {
        queue.withLock { queue in
            queue.append(element, to: laneID.index)
        }
        wakeup.signal()
    }
    
    func popFirst() -> (laneID: LaneID, element: QueuedJob)? {
        queue.withLock { queue in
            guard let (bucketIndex, element) = queue.popFirst() else {
                return nil
            }
            return (LaneID(index: bucketIndex), element)
        }
    }
    
    func wait(detectingQuiescence: Bool) async -> WaitResult {
        await withTaskCancellationShield {
            await withTaskGroup { group in
                group.addTask {
                    _ = await self.wakeup.wait()
                    return JobPriorityQueue.WaitResult.activityDetected
                }
                if detectingQuiescence {
                    group.addTask {
                        for _ in 0..<1000 {
                            if Task.isCancelled { return .activityDetected }
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
    
    func signal() {
        wakeup.signal()
    }
}
