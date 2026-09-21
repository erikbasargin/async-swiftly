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
    
    struct Generation: Hashable, Sendable {
        fileprivate let value: UInt64
    }
    
    enum Action {
        case signal
        case cancel(Generation)
        case wait(Generation, Waiter)
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
    
    private var generation = Generation(value: 0)
    private var pendingSignal = false
    private var waitState: WaitState?
    
    mutating func registerWait() -> Generation {
        guard waitState == nil else {
            preconditionFailure("Attempt to register wait when already waiting")
        }
        
        generation = Generation(value: generation.value + 1)
        waitState = .waiting(nil)
        return generation
    }
    
    mutating func reduce(action: Action) -> Effect? {
        switch action {
        case .signal:
            singnal()
        case .cancel(let generation) where generation == self.generation:
            cancel()
        case .wait(_, let waiter):
            wait(waiter)
        default:
            nil
        }
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
            pendingSignal = true
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

        case .waiting(nil) where pendingSignal:
            waitState = nil
            pendingSignal = false
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
