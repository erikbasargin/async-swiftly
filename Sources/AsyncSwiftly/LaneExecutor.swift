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

final class LaneExecutor: TaskExecutor, SerialExecutor {
    
    let laneID: LaneID
    let queue: JobPriorityQueue
    let unownedExecutor: UnownedSerialExecutor
    
    init(laneID: LaneID, queue: JobPriorityQueue, unownedExecutor: UnownedSerialExecutor) {
        self.laneID = laneID
        self.queue = queue
        self.unownedExecutor = unownedExecutor
    }
    
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unownedExecutor
    }
    
    func enqueue(_ job: consuming ExecutorJob) {
        queue.append(QueuedJob(job, taskExecutor: asUnownedTaskExecutor()), to: laneID)
    }
}
