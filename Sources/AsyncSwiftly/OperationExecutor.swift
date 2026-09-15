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

final class OperationExecutor: TaskExecutor, SerialExecutor {
    
    let id: Int
    let queue: JobPriorityQueue
    let unownedExecutor: UnownedSerialExecutor
    
    init(id: Int, queue: JobPriorityQueue, unownedExecutor: UnownedSerialExecutor) {
        self.id = id
        self.queue = queue
        self.unownedExecutor = unownedExecutor
    }
    
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unownedExecutor
    }
    
    func enqueue(_ job: consuming ExecutorJob) {
        queue.append(UnownedJob(job), to: id)
    }
}
