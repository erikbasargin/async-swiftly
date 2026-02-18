import ManualClock
import Testing

struct ManualClockTests {

    @Test func `Sleep resumes only after sufficient manual advance`() async throws {
        let clock = ManualClock()
        let task = Task {
            try await clock.sleep(until: .init(when: .step(2)))
            return 42
        }

        clock.advance(by: .step(1))
        try await Task.sleep(for: .milliseconds(20))
        #expect(task.isCancelled == false)

        clock.advance(by: .step(1))
        #expect(try await task.value == 42)
    }

    @Test func `Advance to instant updates current time and resumes sleepers`() async throws {
        let clock = ManualClock()
        let task = Task {
            try await clock.sleep(until: .init(when: .step(3)))
            return "done"
        }

        clock.advance(to: .init(when: .step(3)))
        #expect(clock.now == .init(when: .step(3)))
        #expect(try await task.value == "done")
    }

    @Test func `Sleep throws cancellation error when waiting task is cancelled`() async throws {
        let clock = ManualClock()
        let task = Task {
            try await clock.sleep(until: .init(when: .step(10)))
        }

        await Task.yield()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
