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

public func withTestTaskGroup(body: (isolated TestActor) -> Void) async throws {
    let actor = TestActor()
    await body(actor)
}

public actor TestActor {
    
}
