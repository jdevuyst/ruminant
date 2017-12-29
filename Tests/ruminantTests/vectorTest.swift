//
//  ruminantTests
//
//  Created by Stefan Boether on 28.12.17.


import XCTest
@testable import ruminant

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
    
    func testCompare() {
        let seqA : PersistentVector<Int> = [0,1,2,3,5,6]
        
        let seqB = PersistentVector<Int>().conj(0).conj(1).conj(2).conj(3).conj(5).conj(6)
        
        XCTAssert(seqA == seqB, "Sequences not equal")
    }
    
    func testSubVector() {
        let arr = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377,
                   610, 987, 1597, 2584, 4181,6765, 10946, 17711, 28657, 46368,
                   75025, 121393, 196418, 317811, 514229,832040, 1346269]
        let seq = PersistentVector(arr)
        
        XCTAssert( PersistentVector(arr[...5]) == seq[...5])
        XCTAssert( PersistentVector(arr[..<5]) == seq[..<5])
        
        XCTAssert( PersistentVector(arr[5...15]) == seq[5...15])
        XCTAssert( PersistentVector(arr[5..<15]) == seq[5..<15])
        
        XCTAssert( PersistentVector(arr[5...]) == seq[5...])
    }
}
