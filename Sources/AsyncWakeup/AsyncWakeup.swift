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
    }
    
    private enum WaitState {
        case idle
        case waiting(CheckedContinuation<Result, Never>?)
        case completed(Result)
    }
    
    private struct State {
        var pendingResume = false
        var waitState = WaitState.idle
    }
    
    private let state = Mutex(State())
    
    public init() {}
    
    public func signal() {
        resolve(action: .signal)
    }
    
    public func wait() async -> Result {
        state.withLock { state in
            guard case .idle = state.waitState else {
                preconditionFailure()
            }
            
            state.waitState = .waiting(nil)
        }
        
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let result: Result? = state.withLock { state in
                    switch state.waitState {
                    case .completed(let result):
                        state.waitState = .idle
                        return result
                    case .waiting(nil) where state.pendingResume:
                        state = State()
                        return .resumed
                    case .waiting(nil):
                        state.waitState = .waiting(continuation)
                        return nil
                    case .idle, .waiting:
                        preconditionFailure("Invalid state detected: \(state)")
                    }
                }
                
                if let result {
                    continuation.resume(returning: result)
                }
            }
        } onCancel: { 
            resolve(action: .cancel)
        }
    }
    
    private func resolve(action: Action) {
        let next: (Result, CheckedContinuation<Result, Never>)? = state.withLock { state in
            switch (action, state.waitState) {
            case let (.signal, .waiting(continuation?)):
                state.waitState = .idle
                return (.resumed, continuation)
                
            case (.signal, .idle):
                state.pendingResume = true
                return nil
                
            case (.signal, .waiting(nil)):
                state.waitState = .completed(.resumed)
                return nil
                
            case (.signal, .completed):
                state.pendingResume = true
                return nil
                
            case let (.cancel, .waiting(continuation?)):
                state.waitState = .idle
                return (.cancelled, continuation)
                
            case (.cancel, .waiting(nil)):
                state.waitState = .completed(.cancelled)
                return nil
                
            case (.cancel, .idle):
                return nil
                
            case (.cancel, .completed):
                return nil
            }
        }
        
        if let (result, continuation) = next {
            continuation.resume(returning: result)
        }
    }
}
