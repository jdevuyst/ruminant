//
//  UtilTest.swift
//  ruminant
//
//  Created by Stefan Boether on 28.12.17.
//  Copyright © 2017 Gloria42. All rights reserved.
//

import XCTest

class UtilTest: XCTestCase {

    func testArrayPop() {
        let fibonacci = [0,1,1,3,5,8,13]
        let newArray = arrayPop(fibonacci)
        XCTAssertEqual([0,1,1,3,5,8], newArray, "arrayPop")
    }
    
    func testArrayConj() {
        let fibonacci = [0,1,1,3,5,8]
        let newArray = arrayConj(fibonacci, val:13)
        XCTAssertEqual([0,1,1,3,5,8,13], newArray,"arrayConj")
    }
    
    func testArrayAssoc() {
        var fibonacci = [0,1,42,3,5,8,13]
        let newArray = arrayAssoc(&fibonacci, idx: 2, val: 1)
        XCTAssertEqual([0,1,1,3,5,8,13], newArray, "arrayAssoc")
        XCTAssertEqual(1, fibonacci[2])
    }
    
    func testSeqDescription() {
        let fibonacci = [0,1,1,3,5,8,13]
        let description = seqDescription(xs: fibonacci, ldelim: "<", rdelim: ">")
        XCTAssertEqual("<0, 1, 1, 3, 5, 8, 13>", description, "seqDescription")
    }
    
    
    func testSeqDebugDescription() {
        let fibonacci = [0,1,1,3,5,8,13]
        let description = seqDebugDescription(xs: fibonacci, ldelim: "[", rdelim: "]")
        XCTAssertEqual("[0, 1, 1, 11, 101, 1000, 1101]", description, "seqDebugDescription")
    }
}

// For testSeqDebugDescription only !!
extension Int : CustomDebugStringConvertible {
    public var debugDescription : String {
        return String(self, radix: 2)
    }
}
