//
//  SchadulingTaskGroup.swift
//  async-swiftly
//
//  Created by Erik Basargin on 25/06/2025.
//

import os
import Foundation
import DequeModule

@inlinable
public func withSchedulingTaskGroup(
    isolation: isolated (any Actor)? = #isolation,
    body: (inout SchedulingTaskGroup) -> Void
) async throws {
    try await withThrowingDiscardingTaskGroup(isolation: isolation) { baseGroup in
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
                queue.advance()
            }
            await withTaskExecutorPreference(executor, operation: operation)
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
            var scheduledWork: [Instant: Deque<Work>] = [:]
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
                $0.scheduledWork[deadline, default: []].append(work)
            }
        }
    }
}

extension SchedulingTaskGroup.WorkQueue: AsyncSequence {
    
    struct Iterator: AsyncIteratorProtocol {
        
        let state: OSAllocatedUnfairLock<State>
        
        func next() async throws -> Work? {
            state.withLock {
                var instant = Instant.init(when: .zero)
                
                repeat {
                    if let work = $0.scheduledWork[instant]?.popFirst() {
                        return work
                    } else {
                        instant = instant.advanced(by: .step(1))
                    }
                } while instant <= $0.now
                
                return nil
            }
        }
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(state: state)
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
