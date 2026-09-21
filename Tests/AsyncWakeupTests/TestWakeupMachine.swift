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

    @Test func `Cancellation losing to signal does not affect next wait`() {
        var machine = WakeupMachine<String>()

        let generationOne = machine.registerWait()
        
        #expect(machine.reduce(action: .wait(generationOne, "first")) == nil)
        #expect(machine.reduce(action: .signal) == .resume("first"))
        #expect(machine.reduce(action: .cancel(generationOne)) == nil)

        let generationTwo = machine.registerWait()
        
        #expect(machine.reduce(action: .wait(generationTwo, "second")) == nil)
        #expect(machine.reduce(action: .signal) == .resume("second"))
    }
    
    @Test func `Signal is preserved for next wait when current wait is cancelling`() {
        var machine = WakeupMachine<String>()
        
        let generationOne = machine.registerWait()
        
        #expect(machine.reduce(action: .cancel(generationOne)) == nil)
        #expect(machine.reduce(action: .signal) == nil)
        #expect(machine.reduce(action: .wait(generationOne, "first")) == .cancel("first"))
        
        let generationTwo = machine.registerWait()
        
        #expect(machine.reduce(action: .wait(generationTwo, "second")) == .resume("second"))
    }
    
    @Test func `Signal is preserved for next wait when current wait is finishing`() {
        var machine = WakeupMachine<String>()
        
        let generationOne = machine.registerWait()
        
        #expect(machine.reduce(action: .signal) == nil)
        #expect(machine.reduce(action: .signal) == nil)
        #expect(machine.reduce(action: .wait(generationOne, "first")) == .resume("first"))
        
        let generationTwo = machine.registerWait()
        
        #expect(machine.reduce(action: .wait(generationTwo, "second")) == .resume("second"))
    }
}
