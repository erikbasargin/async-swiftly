import ManualClock
import Testing
import Synchronization

@Suite(.timeLimit(.minutes(1))) struct ManualClockTests {

    @Test func `Sleep resumes only after sufficient manual advance`() async throws {
        let clock = ManualClock()
        let completed = Mutex(false)
        let task = Task.immediate {
            try await clock.sleep(until: .init(when: .step(3)))
            completed.withLock { $0 = true }
        }
        
        #expect(completed.withLock(\.self) == false)
        clock.advance(by: .step(1))
        #expect(completed.withLock(\.self) == false)
        clock.advance(by: .step(1))
        #expect(completed.withLock(\.self) == false)
        clock.advance(by: .step(1))
        
        try await task.value
        
        #expect(completed.withLock(\.self) == true)
    }

    @Test func `Sleep throws cancellation error when waiting task is cancelled`() async throws {
        let clock = ManualClock()
        let cancelled = Mutex(false)
        let task = Task.immediate {
            do {
                try await clock.sleep(until: .init(when: .step(10)))
            } catch is CancellationError {
                cancelled.withLock { $0 = true }
            }
        }
        
        #expect(cancelled.withLock(\.self) == false)
        
        task.cancel()
        
        try await task.value
        
        #expect(cancelled.withLock(\.self) == true)
    }
    
    @Test func `Sleep throws cancellation error when waiting task is cancelled after advancing the clock`() async throws {
        let clock = ManualClock()
        let cancelled = Mutex(false)
        let task = Task.immediate {
            do {
                try await clock.sleep(until: .init(when: .step(10)))
            } catch is CancellationError {
                cancelled.withLock { $0 = true }
            }
        }
        
        #expect(cancelled.withLock(\.self) == false)
        clock.advance(by: .step(1))
        #expect(cancelled.withLock(\.self) == false)
        task.cancel()
        
        try await task.value
        
        #expect(cancelled.withLock(\.self) == true)
    }

    @Test func `Sleep completes immediately when deadline equals now`() async throws {
        let clock = ManualClock()
        let completed = Mutex(false)
        let deadline = clock.now

        let task = Task.immediate {
            try await clock.sleep(until: deadline)
            completed.withLock { $0 = true }
        }
        
        #expect(completed.withLock(\.self) == true)

        try await task.value

        #expect(completed.withLock(\.self) == true)
    }

    @Test func `Sleep completes immediately when deadline is in the past`() async throws {
        let clock = ManualClock(initialInstant: .init(when: .step(5)))
        let completed = Mutex(false)

        let task = Task.immediate {
            try await clock.sleep(until: .init(when: .step(3)))
            completed.withLock { $0 = true }
        }
        
        #expect(completed.withLock(\.self) == true)

        try await task.value

        #expect(completed.withLock(\.self) == true)
    }

    @Test func `Sleep throws cancellation error when deadline equals now given task is cancelled`() async throws {
        let clock = ManualClock()
        let deadline = clock.now

        let task = Task.immediate {
            while !Task.isCancelled {
                await Task.yield()
            }
            
            try await clock.sleep(until: deadline)
        }

        task.cancel()
        
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func `Sleep throws cancellation error when deadline is in the past given task is cancelled`() async throws {
        let clock = ManualClock(initialInstant: .init(when: .step(5)))

        let task = Task.immediate {
            while !Task.isCancelled {
                await Task.yield()
            }
            
            try await clock.sleep(until: .init(when: .step(3)))
        }

        task.cancel()
        
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func `Advance to past instant does not move clock backwards`() async throws {
        let clock = ManualClock(initialInstant: .init(when: .step(5)))

        clock.advance(to: .init(when: .step(3)))

        #expect(clock.now == .init(when: .step(5)))
    }

    @Test func `Concurrent advancing does not overshoot`() async throws {
        let target = ManualClock.Step.step(5)
        let clock = ManualClock()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    for _ in 0..<300 {
                        clock.advance(to: .init(when: target))
                        await Task.yield()
                    }
                }
            }
        }
        
        #expect(clock.now.when == target)
    }
}
