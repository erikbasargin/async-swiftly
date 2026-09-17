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
    
    private enum State {
        case waiting(CheckedContinuation<Result, Never>?)
        case completed(Result)
    }
    
    private let state = Mutex(State.waiting(nil))
    
    public init() {}
    
    public func signal() {
        resolve(action: .signal)
    }
    
    public func wait() async -> Result {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let result: Result? = state.withLock { state in
                    switch state {
                    case .completed(let result):
                        state = .waiting(nil)
                        return result
                    case .waiting(nil):
                        state = .waiting(continuation)
                        return nil
                    case .waiting:
                        preconditionFailure()
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
            switch (action, state) {
            case let (.signal, .waiting(continuation?)):
                state = .waiting(nil)
                return (.resumed, continuation)
                
            case (.signal, .waiting(nil)):
                state = .completed(.resumed)
                return nil
                
            case let (.cancel, .waiting(continuation?)):
                state = .completed(.cancelled)
                return (.cancelled, continuation)
                
            case (.cancel, .waiting(nil)):
                state = .completed(.cancelled)
                return nil
                
            default:
                return nil
            }
        }
        
        if let (result, continuation) = next {
            continuation.resume(returning: result)
        }
    }
}
