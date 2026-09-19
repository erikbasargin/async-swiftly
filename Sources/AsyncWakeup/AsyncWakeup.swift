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

import Synchronization

public struct AsyncWakeup: ~Copyable, Sendable {
    
    public enum Result: Sendable, Equatable {
        case resumed
        case cancelled
    }
    
    private typealias StateMachine = WakeupMachine<CheckedContinuation<Result, Never>>
    
    private let machine = Mutex(StateMachine())
    
    public init() {}
    
    public func signal() {
        resolve(action: .signal)
    }
    
    public func wait() async -> Result {
        resolve(action: .registerWait)
        
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                resolve(action: .wait(continuation))
            }
        } onCancel: { 
            resolve(action: .cancel)
        }
    }
    
    private func resolve(action: StateMachine.Action) {
        let effect = machine.withLock { machine in
            machine.reduce(action: action)
        }
        
        switch effect {
        case .resume(let continuation):
            continuation.resume(returning: .resumed)
        case .cancel(let continuation):
            continuation.resume(returning: .cancelled)
        case .terminateProcess(let message):
            preconditionFailure(message)
        case nil:
            break
        }
    }
}
