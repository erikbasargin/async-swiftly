//
//  Async.swift
//  async-swiftly
//
//  Created by Erik Basargin on 29/06/2025.
//

import os

struct AsyncSizedStream<Element: Sendable>: Sendable {
    
    typealias Base = AsyncStream<Element>
    
    struct Continuation: Sendable {
        
        typealias YieldResult = Base.Continuation.YieldResult
        
        private let base: Base.Continuation
        private let counter: OSAllocatedUnfairLock<Int>
        
        init(base: Base.Continuation, counter: OSAllocatedUnfairLock<Int>) {
            self.base = base
            self.counter = counter
        }
        
        @discardableResult
        func yield(_ value: Element) -> Base.Continuation.YieldResult {
            counter.withLock { size in
                let result = base.yield(value)
                if case .enqueued = result {
                    size += 1
                }
                return result
            }
        }
        
        func finish() {
            base.finish()
        }
    }
    
    private let base: Base
    private let counter: OSAllocatedUnfairLock<Int>
    
    private init(base: Base, counter: OSAllocatedUnfairLock<Int>) {
        self.base = base
        self.counter = counter
    }
}

extension AsyncSizedStream: AsyncSequence {
    
    struct Iterator: AsyncIteratorProtocol {
        
        var base: AsyncStream<Element>.Iterator
        let counter: OSAllocatedUnfairLock<Int>
        
        mutating func next() async -> Element? {
            switch await base.next() {
            case .none:
                return nil
            case .some(let value):
                counter.withLock { $0 -= 1 }
                return value
            }
        }
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), counter: counter)
    }
}

extension AsyncSizedStream {
    
    static func makeStream(
        of elementType: Element.Type = Element.self,
    ) -> (stream: AsyncSizedStream<Element>, continuation: AsyncSizedStream<Element>.Continuation) {
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let base = AsyncStream.makeStream(of: Element.self)
        let stream = AsyncSizedStream(base: base.stream, counter: counter)
        let continuation = AsyncSizedStream.Continuation(base: base.continuation, counter: counter)
        return (stream, continuation)
    }
}

extension AsyncSizedStream {
    
    var isEmpty: Bool {
        counter.withLock { $0 == 0 }
    }
    
    func pop() async -> Element? {
        guard !isEmpty else { return nil }
        
        var iterator = makeAsyncIterator()
        return await iterator.next()
    }
}
