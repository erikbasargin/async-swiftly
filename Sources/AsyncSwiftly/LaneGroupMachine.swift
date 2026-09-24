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

struct LaneGroupMachine<Waiter> {
    
    enum DrainAction {
        case resume(Waiter?)
        case wait
        case detectBlock
        case complete
    }
    
    private enum LaneState {
        case pending(Waiter?)
        case active
        case finished
        
        var isFinished: Bool {
            if case .finished = self {
                true
            } else {
                false
            }
        }
    }
    
    private var lanes: [LaneState] = []
    private var nextLaneID = 0
    
    mutating func registerLane() -> Int {
        let id = lanes.count
        lanes.append(.pending(nil))
        return id
    }
    
    func isReleased(laneID: Int) -> Bool {
        laneID < nextLaneID
    }

    func isPending(laneID: Int) -> Bool {
        if case .pending = lanes[laneID] {
            true
        } else {
            false
        }
    }
    
    mutating func wait(laneID: Int, waiter: Waiter) {
        guard case .pending(let existingWaiter) = lanes[laneID] else {
            preconditionFailure("Only a pending lane can wait")
        }
        assert(existingWaiter == nil)
        lanes[laneID] = .pending(waiter)
    }
    
    mutating func finish(laneID: Int) {
        lanes[laneID] = .finished
    }
    
    mutating func nextDrainAction() -> DrainAction {
        if lanes.allSatisfy(\.isFinished) {
            return .complete
        }
        
        guard nextLaneID < lanes.count else {
            return .wait
        }
        
        let previousState = nextLaneID == 0 ? nil : lanes[nextLaneID - 1]
        switch previousState {
        case nil, .finished:
            return .resume(releaseNextLane())
        case .active:
            return .detectBlock
        case .pending:
            preconditionFailure("The previous lane must already be released")
        }
    }
    
    mutating func releaseNextLane() -> Waiter? {
        guard case .pending(let waiter) = lanes[nextLaneID] else {
            preconditionFailure("A lane can only be released once")
        }
        lanes[nextLaneID] = .active
        nextLaneID += 1
        return waiter
    }
}
