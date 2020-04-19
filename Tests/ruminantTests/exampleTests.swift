//
//  exampleTests.swift
//  ruminantTests
//
//  Created by Jonas De Vuyst on 19/4/20.
//

import XCTest
import ruminant

class ExampleTest: XCTestCase {
    func testCoreOperations() {
        let v: PersistentVector = ["a", "b", "c"]
        let v2 = v.conj("d").assoc(index: 2, "C")
        XCTAssertEqual(v, ["a", "b", "c"])
        XCTAssertEqual(v2, ["a", "b", "C", "d"])
        XCTAssert(v.pop() == v2[0..<2])
        XCTAssertEqual(v.map {$0.uppercased()}, ["A", "B", "C"])
        XCTAssertEqual(v[1], "b")
        XCTAssert(v[0...1] == v.pop())
    }

    func testTransientVectors() {
        let v: PersistentVector = ["a", "b", "c"]
        var tmp = v.transient()
        tmp = tmp.pop()
        tmp = tmp.conj("3")
        tmp = tmp.conj("4")
        XCTAssert(tmp.persistent() == ["a", "b", "3", "4"])
    }
}
