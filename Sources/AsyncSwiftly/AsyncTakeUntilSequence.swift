//
//  AsyncTakeUntilSequence.swift
//  async-swiftly
//
//  Created by Erik Basargin on 05/07/2025.
//

import AsyncAlgorithms
import AsyncMaterializedSequence

extension AsyncSequence {
    
    func takeUntil<TriggerSequence: AsyncSequence>(
        _ trigger: TriggerSequence
    ) -> AsyncTakeUntilSequence<Self, TriggerSequence> where Self: Sendable, Self.Element: Sendable, TriggerSequence: Sendable, TriggerSequence.Element: Sendable {
        .init(self, trigger)
    }
}

struct AsyncTakeUntilSequence<
    Base1: AsyncSequence,
    Base2: AsyncSequence
>: AsyncSequence, Sendable where Base1: Sendable, Base1.Element: Sendable, Base2: Sendable, Base2.Element: Sendable {
    
    typealias Base = AsyncCombineLatest2Sequence<
        AsyncMaterializedSequence<Base1>,
        AsyncMerge2Sequence<AsyncThrowingMapSequence<AsyncSyncSequence<[Int]>, Bool>, AsyncThrowingMapSequence<Base2, Bool>>
    >
    
    let base: Base
    
    init(_ base1: Base1, _ base2: Base2) {
        let startWith = [1].async.map { _ throws in false }
        let triggerBase = base2.map { _ throws in true }
        let trigger = merge(startWith, triggerBase)
        base = combineLatest(base1.materialize(), trigger)
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }
    
    struct Iterator: AsyncIteratorProtocol {
        
        var base: Base.AsyncIterator
        
        mutating func next() async throws -> Base1.Element? {
            guard let value = try await base.next() else {
                return nil
            }
            
            switch value {
            case (.value(let element), false):
                return element
            case (.completed, false), (_, true):
                return nil
            }
        }
    }
}
