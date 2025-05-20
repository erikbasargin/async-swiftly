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
        await #expect(stream.collect().isEmpty == true)
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