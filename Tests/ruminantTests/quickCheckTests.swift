//
//  quickCheckTests.swift
//  ruminantTests
//
//  Created by Jonas De Vuyst on 18/4/20.
//

import XCTest
import SwiftCheck
@testable import ruminant

class QuickCheckTest: XCTestCase {

//    func testConjRandomized() {
//        let el1 = Randomized.element()
//        let el2 = Randomized.element()
//
//        Randomized.assertEquivalent(
//            transientUpdate: { $0.conj(el1) },
//            update: { $0.conj(el2) },
//            equivalentArrayUpdate: { $0 += [el1, el2] })
//    }
//
//    func testPopRandomized() {
//        Randomized.assertEquivalent(
//            transientUpdate: { $0.pop()  },
//            update: { $0.pop() },
//            equivalentArrayUpdate: { arr in
//                arr.removeLast()
//                arr.removeLast() },
//            minimumSize: 2)
//    }
//
//    func testAssocRandomized() {
//        let el1 = Randomized.element()
//        let el2 = Randomized.element()
//
//        var idx1: Int!
//        var idx2: Int!
//
//        Randomized.assertEquivalent(
//            initWithSize: { size in
//                idx1 = Randomized.index(forSize: size)
//                idx2 = Randomized.index(forSize: size) },
//            transientUpdate: { $0.assoc(index: idx1, el1) },
//            update: { $0.assoc(index: idx2, el2) },
//            equivalentArrayUpdate: { arr in
//                arr[idx1] = el1
//                arr[idx2] = el2 },
//            minimumSize: 2)
//    }
//
//    func testCollection() {
//
//        let seq : PersistentVector<Float> = [0,1,3]
//
//        XCTAssertEqual(0, seq[0], "subscript")
//        XCTAssertEqual(1, seq[1], "subscript")
//        XCTAssertEqual(3, seq[2], "subscript")
//
//        func f(_ x: Int) -> Float {
//            return sqrtf(Float(x))
//        }
//
//        let size = Int(UInt16.max)
//        let empty: PersistentVector<Float> = []
//        var tvec = TransientVector(vector: empty)
//        for i in 0 ..< size {
//            tvec = tvec.conj(f(i))
//        }
//        let vec = tvec.persistent()
//
//        for i in (0 ..< size).reversed() {
//            XCTAssertEqual(f(i), vec[i])
//        }
//    }
//
//    func testCompare() {
//        let seqA : PersistentVector<Int> = [0,1,2,3,5,6]
//
//        let seqB = PersistentVector<Int>().conj(0).conj(1).conj(2).conj(3).conj(5).conj(6)
//
//        XCTAssert(seqA == seqB)
//        XCTAssert(seqA == seqA)
//        XCTAssert(seqA != seqA.conj(7))
//        XCTAssert(seqA != seqA.assoc(index: 1, 9000))
//    }
//
//    func testSubVectorRandomized() {
//        var range: CountableClosedRange<Int>!
//
//        Randomized.assertEquivalent(
//            initWithSize: { size in
//                let idx1 = Randomized.index(forSize: size)
//                let idx2 = Randomized.index(forSize: size)
//                range = min(idx1, idx2) ... max(idx1, idx2) },
//            update: { PersistentVector($0[range]) },
//            equivalentArrayUpdate: { arr in
//                let subArray = arr[range]
//                arr = Array(subArray) },
//            minimumSize: 1)
//    }
//
//    func testConcat() {
//        let v1 : PersistentVector<Int> = [2, 3, 4, 5]
//        let v2 : PersistentVector<Int> = [20, 30, 40, 50]
//        XCTAssertEqual(v1.concat(v2), [2, 3, 4, 5, 20, 30, 40, 50])
//        XCTAssertEqual(PersistentVector(v1[1...2].concat(v2[1...2])), [3, 4, 30, 40])
//    }
}
