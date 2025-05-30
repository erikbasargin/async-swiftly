import AsyncAlgorithms

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension AsyncSequence {
    
    /// Collects all elements of an `AsyncSequence` into an array.
    ///
    /// This method consumes the entire asynchronous sequence and accumulates its elements into a single array.
    /// It returns `nil` if the task is cancelled before any elements are emitted. If the task is cancelled
    /// after emitting elements, the collected elements are still returned. If the sequence completes without
    /// producing any elements, an empty array is returned (unless cancelled).
    ///
    /// Rethrows any error thrown by the underlying asynchronous sequence.
    ///
    /// - Returns: An array of elements from the sequence, or `nil` if the task was cancelled before producing any elements.
    ///
    /// ### Usage Examples
    ///
    /// Collecting elements from a regular sequence:
    /// ```swift
    /// let sequence = [1, 2, 3].async
    /// let result = await sequence.collect()
    /// // result == [1, 2, 3]
    /// ```
    ///
    /// Collecting from an empty sequence:
    /// ```swift
    /// let stream = AsyncStream<Int> { $0.finish() }
    /// let result = await stream.collect()
    /// // result == []
    /// ```
    ///
    /// Handling cancellation:
    /// ```swift
    /// let task = Task {
    ///     let stream = AsyncStream<Int> { _ in }
    ///     return await stream.collect()
    /// }
    /// task.cancel()
    /// let result = await task.value
    /// // result == nil
    /// ```
    ///
    /// Cancellation after yielding some elements:
    /// ```swift
    /// let task = Task {
    ///     let stream = AsyncStream<Int> {
    ///         for i in 1...3 {
    ///             $0.yield(i)
    ///         }
    ///     }
    ///     return await stream.collect()
    /// }
    /// task.cancel()
    /// let result = await task.value
    /// // result == [1, 2, 3]
    /// ```
    ///
    /// Handling errors:
    /// ```swift
    /// struct MyError: Error {}
    ///
    /// let stream = AsyncThrowingStream<Int, Error> {
    ///     throw MyError()
    /// }
    ///
    /// do {
    ///     _ = try await stream.collect()
    /// } catch {
    ///     print("Caught error: \(error)")  // Caught error: MyError
    /// }
    /// ```
    @inlinable package func collect() async rethrows -> [Element]? {
        let elements = try await reduce(into: []) { $0.append($1) }
        return if elements.isEmpty {
            Task.isCancelled ? nil : []
        } else {
            elements
        }
    }
}
