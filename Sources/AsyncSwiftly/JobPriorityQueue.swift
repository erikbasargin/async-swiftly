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
    
    private let wakeup = AsyncWakeup()
    private let queue = Mutex(BucketPriorityQueue<UnownedJob>())
    
    var isEmpty: Bool {
        queue.withLock(\.isEmpty)
    }
    
    func appendLane(_ laneID: LaneID) {
        queue.withLock { queue in
            let bucketIndex = queue.appendBucket()
            assert(bucketIndex == laneID.index)
        }
    }
    
    func append(_ element: UnownedJob, to laneID: LaneID) {
        queue.withLock { queue in
            queue.append(element, to: laneID.index)
        }
        wakeup.signal()
    }
    
    func popFirst() -> (laneID: LaneID, element: UnownedJob)? {
        queue.withLock { queue in
            guard let (bucketIndex, element) = queue.popFirst() else {
                return nil
            }
            return (LaneID(index: bucketIndex), element)
        }
    }
    
    @discardableResult
    func wait() async -> AsyncWakeup.Result {
        await wakeup.wait()
    }
    
    func signal() {
        wakeup.signal()
    }
}
