import Synchronization

public struct ManualClock: Clock, Sendable {

    public struct Step: Hashable, CustomStringConvertible {
        public let rawValue: Int

        public static func step(_ amount: Int) -> Self {
            .init(rawValue: amount)
        }

        public var description: String {
            "step \(rawValue)"
        }
    }

    public struct Instant: Hashable, CustomStringConvertible {
        public let when: Step

        public init(when: Step) {
            self.when = when
        }

        public var description: String {
            "tick \(when)"
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now: Instant
        var nextID: Int = 0
        var sleepers: [Int: Sleeper] = [:]
    }

    private final class Storage: Sendable {
        private let state: Mutex<State>

        init(initialInstant: Instant) {
            state = Mutex(State(now: initialInstant))
        }

        func now() -> Instant {
            state.withLock(\.now)
        }

        func register(deadline: Instant, continuation: CheckedContinuation<Void, any Error>) -> Int? {
            let idAndReadyContinuation: (Int?, CheckedContinuation<Void, any Error>?) = state.withLock {
                if deadline <= $0.now {
                    return (nil, continuation)
                }

                let id = $0.nextID
                $0.nextID += 1
                $0.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                return (id, nil)
            }

            if let continuationToResume = idAndReadyContinuation.1 {
                continuationToResume.resume()
            }

            return idAndReadyContinuation.0
        }

        func cancel(_ id: Int?) {
            guard let id else { return }

            let continuation = state.withLock {
                $0.sleepers.removeValue(forKey: id)?.continuation
            }
            continuation?.resume(throwing: CancellationError())
        }

        func advance(by duration: Step) {
            guard duration > .zero else { return }

            let continuationsToResume = state.withLock { state in
                state.now = state.now.advanced(by: duration)

                var dueContinuations: [CheckedContinuation<Void, any Error>] = []
                for (id, sleeper) in state.sleepers where sleeper.deadline <= state.now {
                    state.sleepers.removeValue(forKey: id)
                    dueContinuations.append(sleeper.continuation)
                }
                return dueContinuations
            }

            for continuation in continuationsToResume {
                continuation.resume()
            }
        }
    }

    private let storage: Storage

    public init(initialInstant: Instant = .init(when: .zero)) {
        storage = Storage(initialInstant: initialInstant)
    }

    public var now: Instant {
        storage.now()
    }

    public var minimumResolution: Step {
        .step(1)
    }

    public func sleep(until deadline: Instant, tolerance: Step? = nil) async throws {
        let sleepID = Mutex<Int?>(nil)

        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let id = storage.register(deadline: deadline, continuation: continuation)
                sleepID.withLock { $0 = id }

                if Task.isCancelled {
                    storage.cancel(id)
                }
            }
        }, onCancel: {
            storage.cancel(sleepID.withLock(\.self))
        })
    }

    public func advance(by duration: Step = .step(1)) {
        storage.advance(by: duration)
    }

    public func advance(to instant: Instant) {
        let duration = now.duration(to: instant)
        storage.advance(by: duration)
    }
}

extension ManualClock.Step: DurationProtocol {

    public static var zero: Self {
        .init(rawValue: 0)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        .init(rawValue: lhs.rawValue - rhs.rawValue)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        .init(rawValue: lhs.rawValue + rhs.rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func / (lhs: Self, rhs: Int) -> Self {
        .init(rawValue: lhs.rawValue / rhs)
    }

    public static func * (lhs: Self, rhs: Int) -> Self {
        .init(rawValue: lhs.rawValue * rhs)
    }

    public static func / (lhs: Self, rhs: Self) -> Double {
        Double(lhs.rawValue) / Double(rhs.rawValue)
    }
}

extension ManualClock.Instant: InstantProtocol {

    public typealias Duration = ManualClock.Step

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.when < rhs.when
    }

    public func advanced(by duration: Duration) -> Self {
        .init(when: when + duration)
    }

    public func duration(to other: Self) -> Duration {
        other.when - when
    }
}
