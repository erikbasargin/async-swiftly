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
        case resume(Waiter)
        case wait
        case detectBlock
        case complete
    }
    
    private enum LaneState {
        case pending(Waiter)
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
    private var nextLaneIndex = 0
    
    mutating func registerLane(waiter: Waiter) -> LaneID {
        let id = LaneID(index: lanes.count)
        lanes.append(.pending(waiter))
        return id
    }
    
    func isReleased(_ laneID: LaneID) -> Bool {
        laneID.index < nextLaneIndex
    }
    
    mutating func finish(_ laneID: LaneID) {
        lanes[laneID.index] = .finished
    }
    
    mutating func nextDrainAction() -> DrainAction {
        if lanes.allSatisfy(\.isFinished) {
            return .complete
        }
        
        guard nextLaneIndex < lanes.count else {
            return .wait
        }
        
        let previousState = nextLaneIndex == 0 ? nil : lanes[nextLaneIndex - 1]
        switch previousState {
        case nil, .finished:
            return .resume(releaseNextLane())
        case .active:
            return .detectBlock
        case .pending:
            preconditionFailure("The previous lane must already be released")
        }
    }
    
    mutating func releaseNextLane() -> Waiter {
        guard case .pending(let waiter) = lanes[nextLaneIndex] else {
            preconditionFailure("A lane can only be released once")
        }
        lanes[nextLaneIndex] = .active
        nextLaneIndex += 1
        return waiter
    }
}
