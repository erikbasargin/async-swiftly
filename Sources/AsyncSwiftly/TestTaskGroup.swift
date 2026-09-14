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

public func withTestTaskGroup(body: @Sendable (isolated TestActor, inout TestTaskGroup) -> Void) async throws {
    let actor = TestActor()
    try await actor.run(body: body)
}

public actor TestActor {
    
    func run(body: @Sendable (isolated TestActor, inout TestTaskGroup) -> Void) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            var testGroup = TestTaskGroup(base: group)
            body(self, &testGroup)
        }
    }
}

public struct TestTaskGroup {
    
    var base: ThrowingDiscardingTaskGroup<any Error>
    
    package mutating func addTask(@_inheritActorContext(always) operation: sending @escaping () async -> Void) {
        base.addTask {
            await operation()
        }
    }
}
