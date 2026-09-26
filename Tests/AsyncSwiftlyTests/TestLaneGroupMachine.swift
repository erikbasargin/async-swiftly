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

@testable import AsyncSwiftly

struct TestLaneGroupMachine {
    
    @Test func `Drain completes given no registered lanes`() {
        var machine = LaneGroupMachine<Int>()
        #expect(machine.reduce(.stalled) == .complete)
    }
    
    @Test func `First lane is released when drain stalls given pending lanes`() {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        let second = machine.registerLane(1)
        
        #expect(machine.isReleased(first) == false)
        #expect(machine.isReleased(second) == false)
        
        #expect(machine.reduce(.stalled) == .releaseLane(0))
        
        #expect(machine.isReleased(first) == true)
        #expect(machine.isReleased(second) == false)
    }
    
    @Test func `Next lane is released when drain stalls given the previous lane has finished`() throws {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        let second = machine.registerLane(1)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.finish(first)
        
        try #require(machine.isReleased(second) == false)
        
        #expect(machine.reduce(.stalled) == .releaseLane(1))
        #expect(machine.isReleased(second) == true)
    }
    
    @Test func `Drain completes when all lanes finish`() throws {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        let second = machine.registerLane(1)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.finish(first)
        
        try #require(machine.reduce(.stalled) == .releaseLane(1))
        machine.finish(second)
        
        #expect(machine.reduce(.stalled) == .complete)
    }
    
    @Test func `Drain suspends without quiescence detection given all lanes are released and one remains unfinished`()
        throws
    {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.activate(first)
        
        #expect(machine.reduce(.stalled) == .suspend(detectingQuiescence: false))
    }
    
    @Test func `Drain suspends without quiescence detection given a starting released lane and a pending lane`() throws
    {
        var machine = LaneGroupMachine<Int>()
        _ = machine.registerLane(0)
        _ = machine.registerLane(1)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        
        #expect(machine.reduce(.stalled) == .suspend(detectingQuiescence: false))
    }
    
    @Test func `Drain suspends to detect quiescence given an active lane and a pending lane`() throws {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        _ = machine.registerLane(1)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.activate(first)
        
        #expect(machine.reduce(.stalled) == .suspend(detectingQuiescence: true))
    }
    
    @Test func `Next lane is released when quiescence is detected given an unfinished earlier lane`() throws {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        let second = machine.registerLane(1)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.activate(first)
        try #require(machine.reduce(.stalled) == .suspend(detectingQuiescence: true))
        try #require(machine.isReleased(second) == false)
        
        #expect(machine.reduce(.quiescenceDetected) == .releaseLane(1))
        #expect(machine.isReleased(second) == true)
    }
    
    @Test func `Release state remains unchanged when drain resumes given a pending lane`() throws {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        let second = machine.registerLane(1)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.activate(first)
        try #require(machine.reduce(.stalled) == .suspend(detectingQuiescence: true))
        
        #expect(machine.reduce(.resumed) == nil)
        #expect(machine.isReleased(first) == true)
        #expect(machine.isReleased(second) == false)
        #expect(machine.reduce(.stalled) == .suspend(detectingQuiescence: true))
    }
    
    @Test func `Drain waits for all lanes to finish when a later lane finishes first`() throws {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        let second = machine.registerLane(1)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.activate(first)
        try #require(machine.reduce(.stalled) == .suspend(detectingQuiescence: true))
        try #require(machine.reduce(.quiescenceDetected) == .releaseLane(1))
        machine.activate(second)
        
        machine.finish(second)
        #expect(machine.reduce(.stalled) == .suspend(detectingQuiescence: false))
        
        machine.finish(first)
        #expect(machine.reduce(.stalled) == .complete)
    }
    
    @Test func `Third lane is released when drain stalls given a finished second lane and an unfinished first lane`()
        throws
    {
        var machine = LaneGroupMachine<Int>()
        let first = machine.registerLane(0)
        let second = machine.registerLane(1)
        let third = machine.registerLane(2)
        
        try #require(machine.reduce(.stalled) == .releaseLane(0))
        machine.activate(first)
        try #require(machine.reduce(.stalled) == .suspend(detectingQuiescence: true))
        try #require(machine.reduce(.quiescenceDetected) == .releaseLane(1))
        machine.finish(second)
        try #require(machine.isReleased(third) == false)
        
        #expect(machine.reduce(.stalled) == .releaseLane(2))
        #expect(machine.isReleased(third) == true)
    }
}
