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
    
    private let continuatio: Mutex<CheckedContinuation<Result, Never>?> = .init(nil)
    
    public init() {}
    
    public func signal() {
        resume(returning: .resumed)
    }
    
    public func wait() async -> Result {
        await withTaskCancellationHandler { 
            await withCheckedContinuation { continuatio in
                self.continuatio.withLock {
                    $0 = continuatio
                }
            }
        } onCancel: { 
            resume(returning: .cancelled)
        }
    }
    
    private func resume(returning result: Result) {
        let continuation: CheckedContinuation<Result, Never>? = continuatio.withLock { stored in
            guard let continuation = stored else {
                return nil
            }
            stored = nil
            return continuation
        }
        
        continuation?.resume(returning: result)
    }
}
