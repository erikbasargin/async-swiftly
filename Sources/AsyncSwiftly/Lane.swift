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

struct LaneID: Hashable, Sendable {
    let index: Int
}

struct Lane: Sendable {
    
    private let laneID: LaneID
    private let gate: AsyncStream<Never>
    
    init(laneID: LaneID, gate: AsyncStream<Never>) {
        self.laneID = laneID
        self.gate = gate
    }
    
    func waitUntilReleased() async -> LaneID {
        await withTaskCancellationShield {
            var iterator = gate.makeAsyncIterator()
            await iterator.next()
        }
        return laneID
    }
}
