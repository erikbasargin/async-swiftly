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

import Foundation

public func withTestTaskGroup(
    timeout seconds: TimeInterval = .infinity,
    body: @Sendable (isolated TestActor, inout TestTaskGroup) -> Void,
) async throws {
    let actor = TestActor()
    try await actor.run(timeout: seconds, body: body)
}

public struct TestTaskGroup: ~Copyable {
    
    let testActor: TestActor
    var base: ThrowingDiscardingTaskGroup<any Error>
    
    package mutating func addTask(operation: @escaping @Sendable (isolated TestActor) async -> Void) {
        let lane = testActor.assumeIsolated { actor in
            actor.makeLane()
        }
        base.addTask { [testActor] in
            let lane = await lane.waitUntilReleased()
            await testActor.runOperation(in: lane, operation: operation)
        }
    }
}
