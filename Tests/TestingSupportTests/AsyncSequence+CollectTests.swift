import Testing
import TestingSupport

struct AsyncSequenceCollectTests {

    @Test(arguments: [
        [],
        [1],
        [1, 2, 3]
    ])
    func `Collect produces array of elements of source sequence`(source: [Int]) async throws {
        let sequence = source.async
        let expectedResult = Array(source)

        await #expect(sequence.collect() == expectedResult)
    }

    @Test func `Collect produces empty array when source sequence is completed without elements`() async throws {
        let stream = AsyncStream<Int> { $0.finish() }
        await #expect(stream.collect()?.isEmpty == true)
    }
    
    @Test func `Collect produces nil when source sequence is cancelled`() async throws {
        let task = Task {
            let stream = AsyncStream<Int> { _ in }
            return await stream.collect()
        }
        
        task.cancel()
        
        await #expect(task.value == nil)
    }
    
    @Test func `Collect produces array of elements when source sequence is cancelled and produced some elements`() async throws {
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

    @Test func `Collect rethrows error when source sequence is failed`() async throws {
        let stream = AsyncThrowingStream {
            throw TestError()
        }

        await #expect(throws: TestError.self) {
            _ = try await stream.collect()
        }
    }
}
