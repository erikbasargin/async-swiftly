//
//  SchadulingTaskGroup.swift
//  async-swiftly
//
//  Created by Erik Basargin on 25/06/2025.
//

import Foundation

public struct SchedulingTaskGroup: ~Copyable {
    
    private let operationQueue = AsyncStream.makeStream(of: (@Sendable () async -> Void).self)
    
    public init() {}
    
    public func addTask(at instant: Int, operation: @Sendable @escaping @isolated(any) () async -> Void) {
        operationQueue.continuation.yield(operation)
    }
    
    public func start() async {
        operationQueue.continuation.finish()
        for await operation in operationQueue.stream {
            await operation()
        }
    }
}
