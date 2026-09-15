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
            var testGroup = TestTaskGroup(testActor: self, base: group)
            body(self, &testGroup)
        }
    }
}

public struct TestTaskGroup: ~Copyable {
    
    let testActor: TestActor
    var base: ThrowingDiscardingTaskGroup<any Error>
    
    package mutating func addTask(operation: @escaping @Sendable (isolated TestActor) async -> Void) {
        _ = base.addImmediateTaskUnlessCancelled { [testActor] in
            await operation(testActor)
        }
    }
}
