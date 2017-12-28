//
//  ruminantTests
//
//  Created by Stefan Boether on 28.12.17.


import XCTest

class VectorTest: XCTestCase {

    func testConj() {
        
        let empty = PersistentVector<Int>()
        XCTAssertEqual(0, empty.count)
        
        let seq = empty.conj(0).conj(1).conj(3)
        XCTAssertEqual(3, seq.count)
        
        XCTAssertEqual("[0, 1, 3]", seq.description)
    }

    func testPop() {
        let empty = PersistentVector<Int>()
        XCTAssertEqual(0, empty.count)
        
        let seq = empty.conj(0).conj(1).conj(3)
        XCTAssertEqual(3, seq.count)
    
        let smallerSeq = seq.pop()
    
        XCTAssertEqual("[0, 1]", smallerSeq.description)
    }
    
    func testAssoc() {
        
        let seq : PersistentVector<Int> = [0,1,3]
        
        let changedSeq = seq.assoc(index: 0, 42)
        
        XCTAssertEqual("[42, 1, 3]", changedSeq.description)
        XCTAssertEqual("[0, 1, 3]", seq.description)
    }
    
    func testCollection() {
        
        let seq : PersistentVector<Int> = [0,1,3]
        
        XCTAssertEqual(1, seq[1], "subscript")
    }
}
