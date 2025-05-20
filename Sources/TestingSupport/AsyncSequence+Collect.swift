import AsyncAlgorithms
import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension AsyncSequence {
    
    /// Returns the array of the elements of the asynchronous sequence.
    @inlinable package func collect() async rethrows -> [Element] {
        try await reduce(into: []) { $0.append($1) }
    }
}
