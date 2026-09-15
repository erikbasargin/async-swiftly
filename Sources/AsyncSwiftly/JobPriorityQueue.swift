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

import BucketPriorityQueue
import Synchronization

final class JobPriorityQueue: Sendable {
    
    private let queue = Mutex(BucketPriorityQueue<UnownedJob>())
    
    var isEmpty: Bool {
        queue.withLock(\.isEmpty)
    }
    
    func appendBucket() -> Int {
        queue.withLock { queue in
            queue.appendBucket()
        }
    }
    
    func append(_ element: UnownedJob, to bucketIndex: Int) {
        queue.withLock { queue in
            queue.append(element, to: bucketIndex)
        }
    }
    
    func popFirst() -> (bucketIndex: Int, element: UnownedJob)? {
        queue.withLock { queue in
            queue.popFirst()
        }
    }
}
