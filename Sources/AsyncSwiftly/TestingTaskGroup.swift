//
//  TestingTaskGroup.swift
//  async-swiftly
//
//  Created by Erik Basargin on 25/06/2025.
//

import os
import Foundation

public struct TimeoutError: LocalizedError {
    public var errorDescription: String? {
        "Testing task group timed out"
    }
    public init() {}
}

@inlinable
public func withTestingTaskGroup(
    isolation: isolated (any Actor)? = #isolation,
    timeout seconds: TimeInterval = .infinity,
    body: (inout TestingTaskGroup) -> Void
) async throws {
    try await withThrowingDiscardingTaskGroup(isolation: isolation) { baseGroup in
        if seconds.isFinite {
            baseGroup.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
        }
        try await withTaskExecutorPreference(SerialTaskExecutor()) {
            var group = TestingTaskGroup(group: baseGroup)
            body(&group)
            try await group.start()
        }
    }
}

@usableFromInline
final class SerialTaskExecutor: TaskExecutor, SerialExecutor {
    
    static let queue = DispatchQueue(label: "TestingTaskGroup.SerialTaskExecutor")
    
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

public struct TestingTaskGroup: ~Copyable {
    
    let queue: WorkQueue
    let clock: Clock
    var group: ThrowingDiscardingTaskGroup<any Error>
    
    public init(group: ThrowingDiscardingTaskGroup<any Error>) {
        self.queue = WorkQueue()
        self.clock = Clock(queue: queue)
        self.group = group
    }
    
    public mutating func addTask(at rawStep: Int, operation: sending @escaping @isolated(any) () async -> Void) {
        let duration = Clock.Step.step(rawStep)
        let instant = Clock.Instant(when: duration)
        let nextInstant = instant.advanced(by: .step(1))
        let executor = OperationExecutor(instant: nextInstant, queue: queue)
        
        let shift: () -> Void = { [queue, clock] in
            var from = clock.now
            
            repeat {
                let step = from
                queue.enqueue(until: step) {
                    queue.dequeue(step)
                    queue.advance()
                }
                from = from.advanced(by: .step(1))
            } while from <= instant
        }
        
        group.addTask { [queue] in
            shift()
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

extension TestingTaskGroup {
    
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

// MARK: - TestingTaskGroup.WorkQueue

extension TestingTaskGroup {
    
    struct WorkQueue: Sendable {
        
        typealias Instant = TestingTaskGroup.Clock.Instant
        typealias Work = @Sendable () -> Void
        
        fileprivate struct State {
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

extension TestingTaskGroup.WorkQueue: AsyncSequence {
    
    struct Iterator: AsyncIteratorProtocol {
        
        fileprivate let state: OSAllocatedUnfairLock<State>
        
        func next() async throws -> Work? {
            func popFirstWork() async -> Work? {
                var instant = Instant.init(when: .zero)
                
                repeat {
                    if let work = await state.withLock(\.scheduledWork)[instant]?.pop() {
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

private struct TaskQueue: Sendable, AsyncSequence {
    
    typealias Work = @Sendable () -> Void
    
    private let base = AsyncSizedStream.makeStream(of: Work.self)
    
    var isEmpty: Bool {
        base.stream.isEmpty
    }
    
    func makeAsyncIterator() -> AsyncSizedStream<Work>.Iterator {
        base.stream.makeAsyncIterator()
    }
    
    func pop() async -> Work? {
        await base.stream.pop()
    }
    
    @discardableResult
    func yield(_ value: @escaping Work) -> AsyncSizedStream<Work>.Continuation.YieldResult {
        base.continuation.yield(value)
    }
    
    func finish() {
        base.continuation.finish()
    }
}

// MARK: - TestingTaskGroup.Clock

extension TestingTaskGroup.Clock: Clock {
    
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

extension TestingTaskGroup.Clock.Step: DurationProtocol {
    
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

extension TestingTaskGroup.Clock.Instant: InstantProtocol {
    
    typealias Duration = TestingTaskGroup.Clock.Step
    
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
