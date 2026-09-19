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
        case .resume(let continuation, let result):
            continuation.resume(returning: result)
        case .terminateProcess(let message):
            preconditionFailure(message)
        case nil:
            break
        }
    }
}

private struct WakeupMachine<Waiter> {
    
    enum Action {
        case signal
        case cancel
        case wait(Waiter)
        case registerWait
    }
    
    enum Effect {
        case resume(Waiter, AsyncWakeup.Result)
        case terminateProcess(String)
    }
    
    private enum WaitState {
        case waiting(Waiter?)
        case finishing
        case cancelling
    }
    
    private var pendingResume = false
    private var waitState: WaitState?
    
    mutating func reduce(action: Action) -> Effect? {
        switch action {
        case .registerWait:
            register()
        case .signal:
            singnal()
        case .cancel:
            cancel()
        case .wait(let waiter):
            wait(waiter)
        }
    }
    
    private mutating func register() -> Effect? {
        guard waitState == nil else {
            return .terminateProcess("Attempt to register wait when already waiting")
        }
        
        waitState = .waiting(nil)
        return nil
    }
    
    private mutating func singnal() -> Effect? {
        switch waitState {
        case let .waiting(continuation?):
            waitState = nil
            return .resume(continuation, .resumed)
            
        case nil:
            pendingResume = true
            return nil
            
        case .waiting(nil):
            waitState = .finishing
            return nil
            
        case .cancelling:
            pendingResume = true
            return nil
        
        case .finishing:
            return nil
        }
    }
    
    private mutating func cancel() -> Effect? {
        switch waitState {
        case let .waiting(continuation?):
            waitState = nil
            return .resume(continuation, .cancelled)
            
        case .waiting(nil):
            waitState = .cancelling
            return nil
            
        case nil:
            return nil
            
        case .cancelling, .finishing:
            return nil
        }
    }
    
    private mutating func wait(_ waiter: Waiter) -> Effect? {
        switch waitState {
        case .finishing:
            waitState = nil
            return .resume(waiter, .resumed)
            
        case .cancelling:
            waitState = nil
            return .resume(waiter, .cancelled)
            
        case .waiting(nil) where pendingResume:
            waitState = nil
            pendingResume = false
            return .resume(waiter, .resumed)
            
        case .waiting(nil):
            waitState = .waiting(waiter)
            return nil
            
        case .waiting:
            return .terminateProcess("Wait is already in progress")
            
        case nil:
            return .terminateProcess("Invalid state")
        }
    }
}

extension WakeupMachine.Action: Sendable where Waiter: Sendable {}
