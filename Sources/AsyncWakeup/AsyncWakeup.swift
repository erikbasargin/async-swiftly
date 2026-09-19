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
    
    private enum Effect {
        case resume(CheckedContinuation<Result, Never>, Result)
        case terminateProcess(String)
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
        let effect = state.withLock { state in
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
        
        switch effect {
        case .resume(let continuation, let result):
            continuation.resume(returning: result)
        case .terminateProcess(let message):
            preconditionFailure(message)
        case nil:
            break
        }
    }
    
    private func registerWaitCommand(_ state: inout State) -> Effect? {
        guard state.waitState == nil else {
            return .terminateProcess("Attempt to register wait when already waiting")
        }
        
        state.waitState = .waiting(nil)
        return nil
    }
    
    private func singnalCommand(_ state: inout State) -> Effect? {
        switch state.waitState {
        case let .waiting(continuation?):
            state.waitState = nil
            return .resume(continuation, .resumed)
            
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
    
    private func cancelCommand(_ state: inout State) -> Effect? {
        switch state.waitState {
        case let .waiting(continuation?):
            state.waitState = nil
            return .resume(continuation, .cancelled)
            
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
    ) -> Effect? {
        switch state.waitState {
        case .completed(let result):
            state.waitState = nil
            return .resume(continuation, result)
            
        case .waiting(nil) where state.pendingResume:
            state = State()
            return .resume(continuation, .resumed)
            
        case .waiting(nil):
            state.waitState = .waiting(continuation)
            return nil
            
        case .waiting:
            return .terminateProcess("Wait is already in progress")
            
        case nil:
            return .terminateProcess("Invalid state")
        }
    }
}
