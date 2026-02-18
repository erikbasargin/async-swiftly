import ManualClock
import Testing
import Synchronization

struct ManualClockTests {

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
}
