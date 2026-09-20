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

struct WakeupMachine<Waiter> {
    
    enum Action {
        case signal
        case cancel
        case wait(Waiter)
        case registerWait
    }
    
    enum Effect {
        case resume(Waiter)
        case cancel(Waiter)
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
        case .waiting(let waiter?):
            waitState = nil
            return .resume(waiter)

        case .waiting(nil):
            waitState = .finishing
            return nil

        case .finishing, .cancelling, nil:
            pendingResume = true
            return nil
        }
    }
    
    private mutating func cancel() -> Effect? {
        switch waitState {
        case .waiting(let waiter?):
            waitState = nil
            return .cancel(waiter)

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
            return .resume(waiter)

        case .cancelling:
            waitState = nil
            return .cancel(waiter)

        case .waiting(nil) where pendingResume:
            waitState = nil
            pendingResume = false
            return .resume(waiter)

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
extension WakeupMachine.Effect: Equatable where Waiter: Equatable {}
