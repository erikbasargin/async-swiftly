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
    
    private enum Action {
        case signal
        case cancel
        case wait(CheckedContinuation<Result, Never>)
        case registerWait
    }
    
    private enum WaitState {
        case waiting(CheckedContinuation<Result, Never>?)
        case completed(Result)
    }
    
    private struct State {
        var pendingResume = false
        var waitState: WaitState?
    }
    
    private let state = Mutex(State())
    
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
    
    private func resolve(action: Action) {
        let next: (Result, CheckedContinuation<Result, Never>)? = state.withLock { state in
            switch action {
            case .registerWait:
                registerWaitCommand(&state)
            case .signal:
                singnalCommand(&state)
            case .cancel:
                cancelCommand(&state)
            case .wait(let continuation):
                waitCommand(&state, continuation: continuation)
            }
        }
        
        if let (result, continuation) = next {
            continuation.resume(returning: result)
        }
    }
    
    private func registerWaitCommand(_ state: inout State) -> (Result, CheckedContinuation<Result, Never>)? {
        guard state.waitState == nil else {
            preconditionFailure()
        }
        
        state.waitState = .waiting(nil)
        return nil
    }
    
    private func singnalCommand(_ state: inout State) -> (Result, CheckedContinuation<Result, Never>)? {
        switch state.waitState {
        case let .waiting(continuation?):
            state.waitState = nil
            return (.resumed, continuation)
            
        case nil:
            state.pendingResume = true
            return nil
            
        case .waiting(nil):
            state.waitState = .completed(.resumed)
            return nil
            
        case .completed(.cancelled):
            state.pendingResume = true
            return nil
        
        case .completed(.resumed):
            return nil
        }
    }
    
    private func cancelCommand(_ state: inout State) -> (Result, CheckedContinuation<Result, Never>)? {
        switch state.waitState {
        case let .waiting(continuation?):
            state.waitState = nil
            return (.cancelled, continuation)
            
        case .waiting(nil):
            state.waitState = .completed(.cancelled)
            return nil
            
        case nil:
            return nil
            
        case .completed:
            return nil
        }
    }
    
    private func waitCommand(
        _ state: inout State,
        continuation: CheckedContinuation<Result, Never>,
    ) -> (Result, CheckedContinuation<Result, Never>)? {
        switch state.waitState {
        case .completed(let result):
            state.waitState = nil
            return (result, continuation)
            
        case .waiting(nil) where state.pendingResume:
            state = State()
            return (.resumed, continuation)
            
        case .waiting(nil):
            state.waitState = .waiting(continuation)
            return nil
            
        case nil, .waiting:
            preconditionFailure("Invalid state detected: \(state)")
        }
    }
}
