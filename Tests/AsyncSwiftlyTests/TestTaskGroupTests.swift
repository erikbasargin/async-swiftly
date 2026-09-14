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

import AsyncSwiftly
import Testing

struct TestTaskGroupTests {
    
    @Test func `Empty registration completes`() async throws {
        try await withTestTaskGroup {}
    }
}
