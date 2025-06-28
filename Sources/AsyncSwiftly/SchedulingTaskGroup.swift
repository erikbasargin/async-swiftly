//
//  SchadulingTaskGroup.swift
//  async-swiftly
//
//  Created by Erik Basargin on 25/06/2025.
//

import os
import Foundation
import DequeModule

public struct TimeoutError: LocalizedError {
    public var errorDescription: String? {
        "Scheduling task group timed out"
    }
    public init() {}
}

@inlinable
public func withSchedulingTaskGroup(
    isolation: isolated (any Actor)? = #isolation,
    timeout seconds: TimeInterval = .infinity,
    body: (inout SchedulingTaskGroup) -> Void
) async throws {
    try await withThrowingDiscardingTaskGroup(isolation: isolation) { baseGroup in
        if seconds.isFinite {
            baseGroup.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
        }
        try await withTaskExecutorPreference(SerialTaskExecutor()) {
            var group = SchedulingTaskGroup(group: baseGroup)
            body(&group)
            try await group.start()
        }
    }
}

@usableFromInline
final class SerialTaskExecutor: TaskExecutor, SerialExecutor {
    
    static let queue = DispatchQueue(label: "SchedulingTaskGroup.SerialTaskExecutor")
    
    @usableFromInline
    init() {}
    
    @usableFromInline
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        Self.queue.async {
            job.runSynchronously(
                isolatedTo: self.asUnownedSerialExecutor(),
                taskExecutor: self.asUnownedTaskExecutor()
            )
        }
    }
}

public struct SchedulingTaskGroup: ~Copyable {
    
    let queue: WorkQueue
    let clock: Clock
    var group: ThrowingDiscardingTaskGroup<any Error>
    
    public init(group: ThrowingDiscardingTaskGroup<any Error>) {
        self.queue = WorkQueue()
        self.clock = Clock(queue: queue)
        self.group = group
    }
    
    public mutating func addTask(at rawStep: Int, operation: sending @escaping @isolated(any) () async -> Void) {
        let instant = Clock.Instant(when: .step(rawStep))
        let nextInstant = instant.advanced(by: .step(1))
        let executor = OperationExecutor(instant: nextInstant, queue: queue)
        
        group.addTask { [queue] in
            queue.enqueue(until: instant) {
                queue.dequeue(instant)
                queue.advance()
            }
            await withTaskExecutorPreference(executor, operation: operation)
            queue.enqueue(until: nextInstant) {
                queue.dequeue(nextInstant)
            }
        }
    }
    
    public consuming func start() async throws {
        for try await work in queue {
            work()
        }
    }
}

extension SchedulingTaskGroup {
    
    struct Clock {
        let queue: WorkQueue
    }
    
    final class OperationExecutor: TaskExecutor {
        
        let instant: Clock.Instant
        let queue: WorkQueue
        
        init(instant: Clock.Instant, queue: WorkQueue) {
            self.instant = instant
            self.queue = queue
        }
        
        func enqueue(_ job: consuming ExecutorJob) {
            let job = UnownedJob(job)
            queue.enqueue(until: instant) {
                job.runSynchronously(on: self.asUnownedTaskExecutor())
            }
        }
    }
}

// MARK: - SchedulingTaskGroup.WorkQueue

extension SchedulingTaskGroup {
    
    struct WorkQueue: Sendable {
        
        typealias Instant = SchedulingTaskGroup.Clock.Instant
        typealias Work = @Sendable () -> Void
        
        struct State {
            var now: Instant = .init(when: .zero)
            var readyToComplete: [Instant: Bool] = [:]
            var scheduledWork: [Instant: TaskQueue] = [:]
        }
        
        var now: Instant {
            state.withLock(\.now)
        }
        
        private let state = OSAllocatedUnfairLock(initialState: State())
        
        func advance() {
            state.withLock {
                $0.now = $0.now.advanced(by: .step(1))
            }
        }
        
        func enqueue(until deadline: Instant, work: @escaping Work) {
            state.withLock {
                if let queue = $0.scheduledWork[deadline] {
                    queue.yield(work)
                } else {
                    let queue = TaskQueue()
                    $0.scheduledWork[deadline] = queue
                    queue.yield(work)
                }
            }
        }
        
        func dequeue(_ instant: Instant) {
            state.withLock {
                $0.readyToComplete[instant] = true
            }
        }
    }
}

extension SchedulingTaskGroup.WorkQueue: AsyncSequence {
    
    struct Iterator: AsyncIteratorProtocol {
        
        let state: OSAllocatedUnfairLock<State>
        
        func next() async throws -> Work? {
            func popFirstWork() async -> Work? {
                var instant = Instant.init(when: .zero)
                
                repeat {
                    if let work = await state.withLock(\.scheduledWork)[instant]?.popFirst() {
                        return work
                    } else {
                        instant = instant.advanced(by: .step(1))
                    }
                } while instant <= state.withLock(\.now)
                
                return nil
            }
            
            repeat {
                if let work = await popFirstWork() {
                    return work
                }
                
                // There is no work currently available. If we're in this situation that means that all operations
                // are suspended (the worst case: we've got into dependecy cicle, it can be resoved only with global timeout).
                // We should not complete unless we've got cancellation or all operations are completed, so,
                // we need to take the first running operation, and await until work is available.
                
                let queue: TaskQueue? = state.withLock {
                    // TODO: - we don't need to run from Step.zero, whenever operation completes we can shift start time
                    var instant = Instant.init(when: .zero)
                    repeat {
                        if let queue = $0.scheduledWork[instant] {
                            if $0.readyToComplete[instant] ?? false {
                                // TODO: - Is it possible to see non-empty queue here, can we reproduce it? Should we register anomaly and return queue to complete remaining work?
                                assert(queue.isEmpty == true, "We should not have scheduled work for this instant")
                                $0.readyToComplete[instant] = nil
                                $0.scheduledWork[instant]?.finish()
                                $0.scheduledWork[instant] = nil
                                instant = instant.advanced(by: .step(1))
                            } else {
                                return queue
                            }
                        } else {
                            instant = instant.advanced(by: .step(1))
                        }
                    } while instant <= $0.now
                    
                    return nil
                }
                
                return await queue?.first(where: { _ in true })
                
            } while true
        }
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(state: state)
    }
}

// MARK: - TaskQueue

struct TaskQueue: Sendable, AsyncSequence {
    
    typealias Work = @Sendable () -> Void
    
    private let queue = AsyncStream.makeStream(of: Work.self)
    private let counter = OSAllocatedUnfairLock(initialState: 0)
    
    var isEmpty: Bool {
        counter.withLock(\.self) == 0
    }
    
    struct Iterator: AsyncIteratorProtocol {
        
        let counter: OSAllocatedUnfairLock<Int>
        var base: AsyncStream<Work>.Iterator
        
        mutating func next() async -> Work? {
            let next = await base.next()
            counter.withLock { $0 -= 1 }
            return next
        }
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(counter: counter, base: queue.stream.makeAsyncIterator())
    }
    
    func popFirst() async -> Work? {
        guard !isEmpty else { return nil }
        
        var iterator = makeAsyncIterator()
        return await iterator.next()
    }
    
    @discardableResult
    public func yield(_ value: @escaping Work) -> AsyncStream<Work>.Continuation.YieldResult {
        counter.withLock { $0 += 1 }
        return queue.continuation.yield(value)
    }
    
    public func finish() {
        queue.continuation.finish()
    }
}

// MARK: - SchedulingTaskGroup.Clock

extension SchedulingTaskGroup.Clock: Clock {
    
    struct Step: Hashable, CustomStringConvertible {
        let rawValue: Int
        
        static func step(_ amount: Int) -> Self {
            Step(rawValue: amount)
        }
        
        var description: String {
            "step \(rawValue)"
        }
    }
    
    struct Instant: Hashable, CustomStringConvertible {
        let when: Step
        
        var description: String {
            "tick \(when)"
        }
    }
    
    var now: Instant {
        queue.now
    }
    
    var minimumResolution: Step {
        .step(1)
    }
    
    func sleep(until deadline: Instant, tolerance: Instant.Duration? = nil) async throws {
        // TODO
    }
}

extension SchedulingTaskGroup.Clock.Step: DurationProtocol {
    
    static var zero: Self {
        .init(rawValue: 0)
    }
    
    static func - (lhs: Self, rhs: Self) -> Self {
        .init(rawValue: lhs.rawValue - rhs.rawValue)
    }
    
    static func + (lhs: Self, rhs: Self) -> Self {
        .init(rawValue: lhs.rawValue + rhs.rawValue)
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    static func / (lhs: Self, rhs: Int) -> Self {
        .init(rawValue: lhs.rawValue / rhs)
    }
    
    static func * (lhs: Self, rhs: Int) -> Self {
        .init(rawValue: lhs.rawValue * rhs)
    }

    static func / (lhs: Self, rhs: Self) -> Double {
        Double(lhs.rawValue) / Double(rhs.rawValue)
    }
}

extension SchedulingTaskGroup.Clock.Instant: InstantProtocol {
    
    typealias Duration = SchedulingTaskGroup.Clock.Step
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.when < rhs.when
    }
    
    func advanced(by duration: Duration) -> Self {
        .init(when: when + duration)
    }

    func duration(to other: Self) -> Duration {
        other.when - when
    }
}
