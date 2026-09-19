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
    
    @Test func `Wait returns cancelled when waiting task is cancelled`() async {
        let wakeup = AsyncWakeup()
        let task = Task.immediate {
            await wakeup.wait()
        }
        
        task.cancel()
        
        #expect(await task.value == .cancelled)
    }
    
    @Test func `Wait returns cancelled when task was already cancelled`() async throws {
        let wakeup = AsyncWakeup()
        let task = Task {
            try withUnsafeCurrentTask { currentTask in
                try #require(currentTask).cancel()
            }
            
            return await wakeup.wait()
        }
        
        #expect(try await task.value == .cancelled)
    }
    
    @Test func `Wait returns resumed when signal is called`() async {
        let wakeup = AsyncWakeup()
        let task = Task.immediate {
            await wakeup.wait()
        }
        
        wakeup.signal()
        
        #expect(await task.value == .resumed)
    }
    
    @Test func `Wait returns resumed when signal was already called`() async {
        let wakeup = AsyncWakeup()
        wakeup.signal()
        
        let task = Task {
            await wakeup.wait()
        }
        
        #expect(await task.value == .resumed)
    }
    
    @Test func `Wait suspends again after consuming a signal`() async {
        let wakeup = AsyncWakeup()
        
        for _ in 0..<3 {
            wakeup.signal()
        }
        
        #expect(await wakeup.wait() == .resumed)
        
        let task = Task.immediate {
            await wakeup.wait()
        }
        
        task.cancel()
        
        #expect(await task.value == .cancelled)
    }
    
    @Test func `Wait suspends again after waking a suspended waiter`() async {
        let wakeup = AsyncWakeup()
        
        let firstWait = Task.immediate {
            await wakeup.wait()
        }
        
        wakeup.signal()
        #expect(await firstWait.value == .resumed)
        
        let secondWait = Task.immediate {
            await wakeup.wait()
        }
        
        secondWait.cancel()
        #expect(await secondWait.value == .cancelled)
    }
    
    @Test func `Wait suspends again after waking a cancelled waiter`() async {
        let wakeup = AsyncWakeup()
        
        let firstWait = Task.immediate {
            await wakeup.wait()
        }
        
        firstWait.cancel()
        #expect(await firstWait.value == .cancelled)
        
        let secondWait = Task.immediate {
            await wakeup.wait()
        }
        
        wakeup.signal()
        #expect(await secondWait.value == .resumed)
    }
    
    @Test func `Cancellation losing to signal does not affect next wait`() async throws {
        let wakeup = AsyncWakeup()
        
        let firstWait = Task.immediate {
            await wakeup.wait()
        }
        
        wakeup.signal()
        firstWait.cancel()
        
        let firstResult = await firstWait.value
        
        try #require(firstResult == .resumed)
        
        let secondWait = Task.immediate {
            await wakeup.wait()
        }
        
        wakeup.signal()
        
        let secondResult = await secondWait.value
        
        #expect(secondResult == .resumed)
    }
    
    @Test func `Signal losing race with cancellation is preserved for next wait`() async throws {
        let wakeup = AsyncWakeup()
        
        let firstWait = Task {
            await wakeup.wait()
        }
        
        await withTaskGroup(of: Void.self) { group in
            group.addImmediateTask {
                firstWait.cancel()
            }
            group.addTask {
                wakeup.signal()
            }
        }
        
        guard await firstWait.value == .cancelled else {
            try Test.cancel("Cancellation must win this iteration")
        }
        
        let secondWait = Task.immediate {
            await wakeup.wait()
        }
        
        secondWait.cancel()
        
        let result = await secondWait.value
        
        #expect(
            result == .resumed,
            "After cancellation wins the first race, the losing signal must be preserved for the next wait.",
        )
    }
}
