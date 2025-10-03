import Testing
import TestingSupport
import AsyncMaterializedSequence

struct AsyncMaterializedSequenceTests {

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func `Materialize produces next events of values of original element`() async throws {
        let source = 1...3
        let sequence = source.async.materialize().prefix(source.count)
        
        await #expect(sequence.collect() == [
            .value(1),
            .value(2),
            .value(3),
        ])
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func `Materialize produces completed event when source sequence completes`() async throws {
        let source = 0..<1
        let sequence = source.async.materialize()
        
        await #expect(sequence.collect() == [
            .value(0),
            .completed(.finished),
        ])
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func `Materialize produces completed event when source sequence is empty`() async throws {
        let source: [Int] = []
        let sequence = source.async.materialize()
        
        await #expect(sequence.collect() == [
            .completed(.finished),
        ])
    }
    
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func `Materialize forwards termination from source when iteration is finished`() async throws {
        let source = 1...3
        
        var iterator = source.async.materialize().makeAsyncIterator()
        while let _ = await iterator.next() {}

        let pastEnd = await iterator.next()
        #expect(pastEnd == nil)
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func `Materialize produces completed event when source sequence throws`() async throws {
        let source = AsyncThrowingStream<Int, any Error> { continuation in
            continuation.finish(throwing: TestError())
        }
        
        let sequence = source.materialize()
        let events = await sequence.collect() ?? []
        
        #expect(events.count == 1)
        
        let event = try #require(events.last)
        
        switch event {
        case .completed(.failure(let error)) where error is TestError:
            break
        default:
            Issue.record("Unexpected event: \(event)")
        }
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func `Materialize produces completed event when source sequence is cancelled`() async throws {
        let trigger = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let source = AsyncStream<Int> { continuation in
            continuation.yield(0)
        }
        let sequence = source.materialize()
        
        let task = Task {
            var firstIteration = false
            return await sequence.reduce(into: [AsyncMaterializedSequence<AsyncStream<Int>>.Event]()) {
                if !firstIteration {
                    firstIteration = true
                    trigger.continuation.finish()
                }
                $0.append($1)
            }
        }
        
        // ensure the other task actually starts
        await trigger.stream.first { _ in true }
        
        // cancellation should ensure the loop finishes
        // without regards to the remaining underlying sequence
        task.cancel()
            
        await #expect(task.value == [
            .value(0),
            .completed(.finished),
        ])
    }
}
