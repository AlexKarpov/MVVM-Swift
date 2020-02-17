import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(MVVM_SwiftTests.allTests),
    ]
}
#endif
