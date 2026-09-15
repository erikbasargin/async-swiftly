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

struct CopyableGroup: Copyable {
    // expected-error@+1 {{stored property 'group' of 'Copyable'-conforming struct 'CopyableGroup' has non-Copyable type 'TestTaskGroup'}}
    var group: TestTaskGroup
}
