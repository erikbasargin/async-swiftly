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

import AsyncWakeup
import Testing

struct TestAsyncWakeup {
    
    @Test func `Wakeup is resumed when scope is cancelled`() async {
        let wakeup = AsyncWakeup()
        let task = Task.immediate {
            await wakeup.wait()
        }
        
        task.cancel()
        
        #expect(await task.value == .cancelled)
    }
    
    @Test func `Wakeup is resumed when task is already cancelled`() async throws {
        let wakeup = AsyncWakeup()
        let task = Task {
            try withUnsafeCurrentTask { currentTask in 
                try #require(currentTask).cancel()
            }
            
            return await wakeup.wait()
        }
        
        #expect(try await task.value == .cancelled)
    }
    
    @Test func `Wakeup is resumed when signal is called`() async {
        let wakeup = AsyncWakeup()
        let task = Task.immediate {
            await wakeup.wait()
        }
        
        wakeup.signal()
        
        #expect(await task.value == .resumed)
    }
}
