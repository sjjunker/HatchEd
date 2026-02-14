//
//  HatchEdTests.swift
//  HatchEdTests
//
//  Created by Sandi Junker on 5/6/25.
//  Uses Swift Testing (Testing framework). See ModelTests.swift, ViewModelTests.swift for more tests.
//  For XCTest-style tests see HatchEdXCTests.swift.
//

import Testing
@testable import HatchEd

struct HatchEdTests {

    @Test func example() async throws {
        #expect(1 + 1 == 2)
    }

    @Test func appImportsSucceed() {
        #expect(PortfolioDesignPattern.general.rawValue == "General")
    }
}
