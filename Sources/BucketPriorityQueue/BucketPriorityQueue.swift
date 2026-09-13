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

import DequeModule

package struct BucketPriorityQueue<Element> {
    
    package private(set) var buckets: [Deque<Element>] = []
    
    package var isEmpty: Bool {
        buckets.first(where: { !$0.isEmpty }) == nil
    }
    
    package init() {}
    
    package mutating func appendBucket() -> Int {
        buckets.append(Deque())
        return buckets.count - 1
    }
    
    package mutating func append(_ element: Element, to bucketIndex: Int) {
        buckets[bucketIndex].append(element)
    }
    
    package mutating func popFirst() -> (bucketIndex: Int, element: Element)? {
        guard let bucketIndex = buckets.firstIndex(where: { !$0.isEmpty }) else {
            return nil
        }
        guard let element = buckets[bucketIndex].popFirst() else {
            return nil
        }
        return (bucketIndex, element)
    }
}
