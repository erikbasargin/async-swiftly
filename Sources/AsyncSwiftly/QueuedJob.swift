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

struct QueuedJob: Sendable {
    
    private let job: UnownedJob
    private let taskExecutor: UnownedTaskExecutor
    
    init(_ job: consuming ExecutorJob, taskExecutor: UnownedTaskExecutor) {
        self.job = UnownedJob(job)
        self.taskExecutor = taskExecutor
    }
    
    func runSynchronously(isolatedTo serialExecutor: UnownedSerialExecutor) {
        job.runSynchronously(isolatedTo: serialExecutor, taskExecutor: taskExecutor)
    }
}
