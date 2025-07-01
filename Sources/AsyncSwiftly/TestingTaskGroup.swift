//
//  TestingTaskGroup.swift
//  async-swiftly
//
//  Created by Erik Basargin on 25/06/2025.
//

import AsyncTrigger
import AsyncAlgorithms
import os
import Foundation

public struct TimeoutError: LocalizedError {
    public var errorDescription: String? {
        "Testing task group timed out"
    }
    public init() {}
}

public enum Event<Element> {
    case value(Int, Element)
    case finished(Int)
}

extension Event: Equatable where Element: Equatable {}
extension Event: Sendable where Element: Sendable {}

@inlinable
public func withTestingTaskGroup<ObservationElement>(
    observing observeType: ObservationElement.Type = ObservationElement.self,
    isolation: isolated (any Actor)? = #isolation,
    timeout seconds: TimeInterval = .infinity,
    body: (inout TestingTaskGroup<ObservationElement>) -> Void
) async throws -> [Int: Array<Event<ObservationElement>>] {
    try await withThrowingDiscardingTaskGroup(isolation: isolation) { baseGroup in
        if seconds.isFinite {
            baseGroup.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
        }
        return try await withTaskExecutorPreference(SerialTaskExecutor()) {
            var group = TestingTaskGroup<ObservationElement>(group: baseGroup)
            body(&group)
            return try await group.start()
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

public struct TestingTaskGroup<ObservationElement: Sendable>: ~Copyable {
    
    let queue: WorkQueue
    let clock: Clock
    var group: ThrowingDiscardingTaskGroup<any Error>
    let events = EventsStorage<ObservationElement>()
    let finishObservationTrigger = AsyncTrigger()
    
    public init(group: ThrowingDiscardingTaskGroup<any Error>) {
        self.queue = WorkQueue()
        self.clock = Clock(queue: queue)
        self.group = group
    }
    
    public mutating func addObserver<Failure: Error>(
        at rawStep: Int,
        observer: @escaping @Sendable () -> some AsyncSequence<ObservationElement, Failure> & Sendable
    ) {
        addTask(at: rawStep) { [clock, events, finishObservationTrigger] in
            do {
                for try await element in observer().takeUntil(finishObservationTrigger) {
                    let tick = clock.now.when.rawValue
                    events.append(.value(tick, element), for: rawStep)
                }
                let tick = clock.now.when.rawValue
                events.append(.finished(tick), for: rawStep)
            } catch {
                let tick = clock.now.when.rawValue
                events.append(.finished(tick), for: rawStep)
            }
        }
    }
    
    public mutating func addTask(at rawStep: Int, operation: sending @escaping @isolated(any) () async -> Void) {
        let instant = Clock.Instant(when: .step(rawStep))
        let executor = OperationExecutor(instant: instant, queue: queue)
        
        group.addTask { [queue] in
            await withTaskExecutorPreference(executor, operation: operation)
            queue.markAsReadyToComplete(instant)
        }
    }
    
    public consuming func start() async throws -> [Int: Array<Event<ObservationElement>>] {
        for try await work in queue {
            work()
        }
        
        finishObservationTrigger.fire()
        
        if queue.isAnyWorkLeft {
            // At this point if work remains unfinished, we've got some tasks that cannot be resolved in provided range of time.
            // Wait until all work finishes or times out.
            
            await queue.waitForAll()
        }
        
        return events.snapshot()
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
            
            queue.prepare(instant)
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
            var end: Instant = .init(when: .zero)
            var readyToComplete: [Instant: Bool] = [:]
            var scheduledWork: [Instant: TaskQueue] = [:]
        }
        
        var now: Instant {
            state.withLock(\.now)
        }
        
        var isAnyWorkLeft: Bool {
            state.withLock {
                !$0.scheduledWork.isEmpty
            }
        }
        
        private let state = OSAllocatedUnfairLock(initialState: State())
        
        func advance(by duration: Clock.Step = .step(1)) {
            state.withLock {
                $0.now = $0.now.advanced(by: duration)
            }
        }
        
        func setNow(_ instant: Instant) {
            state.withLock { $0.now = instant }
        }
        
        func prepare(_ instant: Instant) {
            state.withLock {
                if $0.scheduledWork[instant] == nil {
                    $0.scheduledWork[instant] = TaskQueue()
                    $0.end = $0.end < instant.advanced(by: .step(1)) ? instant.advanced(by: .step(1)) : $0.end
                }
            }
        }
        
        func enqueue(until deadline: Instant, work: @escaping Work) {
            state.withLock {
                $0.scheduledWork[deadline]!.yield(work)
            }
        }
        
        func markAsReadyToComplete(_ instant: Instant) {
            state.withLock {
                $0.readyToComplete[instant] = true
            }
        }
        
        func waitForAll() async {
            while isAnyWorkLeft {
                let queue: TaskQueue? = state.withLock {
                    var instant = Instant.init(when: .zero)
                    while instant < $0.end {
                        if let queue = $0.scheduledWork[instant] {
                            if $0.readyToComplete[instant] ?? false, queue.isEmpty {
                                $0.readyToComplete[instant] = nil
                                $0.scheduledWork[instant]?.finish()
                                $0.scheduledWork[instant] = nil
                                instant = instant.advanced(by: .step(1))
                                return nil
                            } else {
                                return queue
                            }
                        } else {
                            instant = instant.advanced(by: .step(1))
                        }
                    }
                    
                    return nil
                }
                
                if let work = await queue?.pop() {
                    work()
                }
            }
        }
    }
}

extension TestingTaskGroup.WorkQueue: AsyncSequence {
    
    struct Iterator: AsyncIteratorProtocol {
        
        private enum NextAction {
            case popFirstWork(TaskQueue)
            case awaitNextWork(TaskQueue)
        }
        
        fileprivate let state: OSAllocatedUnfairLock<State>
        
        func next() async throws -> Work? {
            func nextAction() -> NextAction? {
                state.withLock {
                    var instant = Instant.init(when: .zero)
                    while $0.now < $0.end {
                        if let queue = $0.scheduledWork[instant] {
                            if $0.readyToComplete[instant] ?? false, queue.isEmpty {
                                $0.readyToComplete[instant] = nil
                                $0.scheduledWork[instant]?.finish()
                                $0.scheduledWork[instant] = nil
                                instant = instant.advanced(by: .step(1))
                                $0.now = $0.now < instant ? instant : $0.now
                                return nil
                            } else if queue.isEmpty {
                                instant = instant.advanced(by: .step(1))
                                $0.now = $0.now < instant ? instant : $0.now
                            } else {
                                return .popFirstWork(queue)
                            }
                        } else {
                            instant = instant.advanced(by: .step(1))
                            $0.now = $0.now < instant ? instant : $0.now
                        }
                    }
                    
                    return nil
                }
            }
            
            repeat {
                for _ in 0..<100 {
                    await Task.yield()
                }
                
                switch nextAction() {
                case let .awaitNextWork(queue):
                    return await queue.first(where: { _ in true })
                case let .popFirstWork(queue):
                    return await queue.pop()
                case .none:
                    continue
                }
            } while state.withLock { $0.now < $0.end }
            
            return nil
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

// MARK: - EventsStorage

struct EventsStorage<Element: Sendable> {
    private let storage: OSAllocatedUnfairLock<[Int: [Event<Element>]]> = .init(initialState: [:])

    func append(_ event: Event<Element>, for observerID: Int) {
        storage.withLock {
            $0[observerID, default: []].append(event)
        }
    }

    func snapshot() -> [Int: [Event<Element>]] {
        storage.withLock(\.self)
    }
}
