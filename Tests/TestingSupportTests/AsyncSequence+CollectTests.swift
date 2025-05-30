import Testing
import TestingSupport

struct AsyncSequenceCollectTests {

    @Test(arguments: [
        [],
        [1],
        [1, 2, 3]
    ])
    func collect_produces_array_of_elements_of_source_sequence(source: [Int]) async throws {
        let sequence = source.async
        let expectedResult = Array(source)

        await #expect(sequence.collect() == expectedResult)
    }

    @Test func collect_produces_empty_array_when_source_sequence_is_completed_without_elements() async throws {
        let stream = AsyncStream<Int> { $0.finish() }
        await #expect(stream.collect()?.isEmpty == true)
    }
    
    @Test func collect_produces_nil_when_source_sequence_is_cancelled() async throws {
        let task = Task {
            let stream = AsyncStream<Int> { _ in }
            return await stream.collect()
        }
        
        task.cancel()
        
        await #expect(task.value == nil)
    }
    
    @Test func collect_produces_array_of_elements_when_source_sequence_is_cancelled_and_produced_some_elements() async throws {
        let source = [1, 2, 3]
        let task = Task {
            let stream = AsyncStream<Int> {
                for value in source {
                    $0.yield(value)
                }
            }
            return await stream.collect()
        }
        
        task.cancel()
        
        await #expect(task.value == source)
    }

    @Test func collect_rethrows_error_when_source_sequence_is_failed() async throws {
        let stream = AsyncThrowingStream {
            throw TestError()
        }

        await #expect(throws: TestError.self) {
            _ = try await stream.collect()
        }
    }
}
