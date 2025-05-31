import AsyncAlgorithms

/// `AsyncTrigger` is intended for suspending asynchronous tasks that should proceed only after a one-time resuming event.
///
/// ### Usage
///
/// ```swift
/// let trigger = AsyncTrigger()
///
/// // These tasks will suspend until the trigger is fired.
/// let task1 = Task {
///     await trigger()
/// }
/// let task2 = Task {
///     await trigger()
/// }
///
/// trigger.fire() // Resumes all awaiting tasks
///
/// let result1 = await task1.value // .triggered
/// let result2 = await task2.value // .triggered
/// ```
///
/// If a task is cancelled before the trigger fires, it returns `.cancelled`:
/// ```swift
/// let trigger = AsyncTrigger()
/// let task = Task {
///     await trigger()
/// }
/// task.cancel()
/// let result = await task.value // .cancelled
/// ```
///
/// `AsyncTrigger` can also be used as an `AsyncSequence`:
/// ```swift
/// let trigger = AsyncTrigger()
/// async let result = trigger.reduce(into: [], { $0.append($1) })
/// trigger.fire()
/// let output = await result // [.triggered]
/// ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct AsyncTrigger: Sendable {
    
    public enum Result: Sendable, Equatable {
        case triggered
        case cancelled
    }

    private let channel = AsyncChannel<Never>()

    public init() {}

    /// Immediately resumes all the suspended operations.
    public func fire() {
        channel.finish()
    }

    @discardableResult
    public func callAsFunction() async -> Result {
        var iterator = makeAsyncIterator()
        // Although next() can return nil, AsyncTrigger.Iterator guarantees that the first value cannot be nil.
        return await iterator.next()!
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension AsyncTrigger: AsyncSequence {
    
    public struct Iterator: AsyncIteratorProtocol {
        
        var base: AsyncChannel<Never>.AsyncIterator
        var hasFired: Bool = false
        
        public mutating func next() async -> AsyncTrigger.Result? {
            guard !hasFired else { return nil }
            
            _ = await base.next()
            hasFired = true
            return Task.isCancelled ? .cancelled : .triggered
        }
    }
    
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: channel.makeAsyncIterator())
    }
}

@available(*, unavailable)
extension AsyncTrigger.Iterator: Sendable {}
