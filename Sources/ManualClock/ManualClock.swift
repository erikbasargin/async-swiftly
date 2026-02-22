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
        let continuation: AsyncStream<Never>.Continuation
    }

    private struct State {
        var now: Instant
        var nextID: Int = 0
        var sleepers: [Int: Sleeper] = [:]
    }
    
    private enum AdvanceKind {
        case by(Step)
        case to(Instant)
    }

    private final class Storage: Sendable {
        private let state: Mutex<State>

        init(initialInstant: Instant) {
            state = Mutex(State(now: initialInstant))
        }

        func now() -> Instant {
            state.withLock(\.now)
        }
        
        func sleep(until deadline: Instant) async throws {
            guard let (id, stream) = register(deadline) else {
                try Task.checkCancellation()
                return
            }
            
            defer {
                _ = state.withLock {
                    $0.sleepers.removeValue(forKey: id)
                }
            }
            
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
            
            try Task.checkCancellation()
        }
        
        private func register(_ deadline: Instant) -> (Int, AsyncStream<Never>)? {
            state.withLock { state in
                guard deadline > state.now else {
                    return nil
                }
                
                let (stream, continuation) = AsyncStream.makeStream(of: Never.self)

                let id = state.nextID
                state.nextID += 1
                state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                return (id, stream)
            }
        }

        func advance(_ kind: AdvanceKind) {
            let continuationsToFinish = state.withLock { state in
                let duration = switch kind {
                case .by(let duration):
                    duration
                case .to(let instant):
                    state.now.duration(to: instant)
                }
                state.now = state.now.advanced(by: max(duration, .zero))

                var dueContinuations: [AsyncStream<Never>.Continuation] = []
                for (id, sleeper) in state.sleepers where sleeper.deadline <= state.now {
                    state.sleepers.removeValue(forKey: id)
                    dueContinuations.append(sleeper.continuation)
                }
                return dueContinuations
            }

            for continuation in continuationsToFinish {
                continuation.finish()
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
        try await storage.sleep(until: deadline)
    }

    public func advance(by duration: Step = .step(1)) {
        storage.advance(.by(duration))
    }

    public func advance(to instant: Instant) {
        storage.advance(.to(instant))
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
