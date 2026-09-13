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

import BucketPriorityQueue
import Testing

struct TestBucketPriorityQueue {
    @Test func `Empty Queue`() async throws {
        var queue = BucketPriorityQueue<Int>()
        #expect(queue.isEmpty == true)
        #expect(queue.popFirst() == nil)
    }
    
    @Test func `Qeueu remains empty when several buckets are added`() throws {
        var queue = BucketPriorityQueue<Int>()
        #expect(queue.appendBucket() == 0)
        #expect(queue.appendBucket() == 1)
        #expect(queue.appendBucket() == 2)
        #expect(queue.isEmpty == true)
    }
    
    @Test func `Queue is not empty when a bucket is added and an element is appended to it`() throws {
        var queue = BucketPriorityQueue<Int>()
        let bucketIndex = queue.appendBucket()
        queue.append(42, to: bucketIndex)
        #expect(queue.isEmpty == false)
        #expect(queue.buckets[bucketIndex] == [42])
    }
    
    @Test(arguments: [-1, 1]) func `Process exits with failure when append is called with an invalid bucket index`(
        invalidBucketIndex: Int
    ) async throws {
        await #expect(processExitsWith: .failure) { [invalidBucketIndex] in
            var queue = BucketPriorityQueue<Int>()
            _ = queue.appendBucket()
            
            queue.append(42, to: invalidBucketIndex)
        }
    }
    
    @Test func `popFirst returns bucket and its first element given queue with one element`() throws {
        var queue = BucketPriorityQueue<Int>()
        let bucketIndex = queue.appendBucket()
        queue.append(42, to: bucketIndex)
        
        let result = queue.popFirst()
        let (poppedBucketIndex, poppedElement) = try #require(result)
        #expect(poppedBucketIndex == bucketIndex)
        #expect(poppedElement == 42)
    }
    
    @Test func `FIFO within a bucket`() throws {
        let elements = ["A", "B", "C"]
        var queue = BucketPriorityQueue<String>()
        let bucketIndex = queue.appendBucket()
        for element in elements {
            queue.append(element, to: bucketIndex)
        }
        
        for element in elements {
            let popped = queue.popFirst()
            let (poppedBucketIndex, poppedElement) = try #require(popped)
            #expect(poppedBucketIndex == bucketIndex)
            #expect(poppedElement == element)
        }
        
        #expect(queue.isEmpty == true)
        #expect(queue.popFirst() == nil)
    }
}
