import Foundation

package struct TestError: LocalizedError, Equatable {
    
    package var errorDescription: String? { 
        "TestError" 
    }
    
    package init() {}
}
