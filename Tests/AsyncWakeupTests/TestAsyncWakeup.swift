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
}
