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

import Testing

@testable import AsyncWakeup

struct TestWakeupMachine {
    
    @Test func `Signal is preserved for next wait when current wait is cancelling`() {
        var machine = WakeupMachine<String>()
        
        #expect(machine.reduce(action: .registerWait) == nil)
        #expect(machine.reduce(action: .cancel) == nil)
        #expect(machine.reduce(action: .signal) == nil)
        #expect(machine.reduce(action: .wait("first")) == .cancel("first"))
        
        #expect(machine.reduce(action: .registerWait) == nil)
        #expect(machine.reduce(action: .wait("second")) == .resume("second"))
    }

    @Test func `Signal is preserved for next wait when current wait is finishing`() {
        var machine = WakeupMachine<String>()

        #expect(machine.reduce(action: .registerWait) == nil)
        #expect(machine.reduce(action: .signal) == nil)
        #expect(machine.reduce(action: .signal) == nil)
        #expect(machine.reduce(action: .wait("first")) == .resume("first"))

        #expect(machine.reduce(action: .registerWait) == nil)
        #expect(machine.reduce(action: .wait("second")) == .resume("second"))
    }
}
