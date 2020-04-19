//
//  ruminantTests
//
//  Created by Stefan Boether on 28.12.17.


import XCTest
@testable import ruminant

private struct Randomized {
    typealias Element = UInt32
    
    static func element() -> Element {
        return arc4random()
    }
    
    static func index(forSize size: Int) -> Int {
        let idx = Int(arc4random_uniform(UInt32(size)))
        assert(idx >= 0)
        assert(idx < size)
        return idx
    }
    
    typealias ArrayUpdate = (inout [Element]) -> Void
    typealias TransientVectorUpdate = (inout TransientVector<Element>) -> TransientVector<Element>
    typealias PersistentVectorUpdate = (PersistentVector<Element>) -> PersistentVector<Element>
    
    static func assertEquivalent(initWithSize: (Int) -> Void = { _ in },
                                 transientUpdate: TransientVectorUpdate = { $0 },
                                 update: PersistentVectorUpdate,
                                 equivalentArrayUpdate: ArrayUpdate,
                                 minimumSize: UInt32 = 0,
                                 increment: UInt32 = 1,
                                 multiply: UInt32 = 2,
                                 maximumSize: UInt32 = UInt32(UInt16.max) * 4,
                                 caller: String = #function) {
        var testSizes: [Int] = []
        let empty: PersistentVector<Element> = []
        
        var lbound = minimumSize
        var ubound = minimumSize
        while ubound <= maximumSize {
            let size = Int(arc4random_uniform(ubound - lbound) + lbound)
            assert(size >= minimumSize)
            initWithSize(size)
            
            var arr: [Element] = []
            arr.reserveCapacity(size)
            
            var tvec = TransientVector(vector: empty)
            
            for _ in 0 ..< size {
                let el = element()
                arr.append(el)
                tvec = tvec.conj(el)
            }
            
            assert(arr.count == size)
            assert(tvec.count == size)
            
            tvec = transientUpdate(&tvec)
            let vec = update(tvec.persistent())
            equivalentArrayUpdate(&arr)
            
            XCTAssertEqual(vec.count, arr.count)
            
            var i = 0
            for el in vec {
                XCTAssertEqual(el, arr[i])
                i += 1
            }
            XCTAssertEqual(i, vec.count)
            
            testSizes.append(size) // tested something meaningful
            
            lbound = ubound
            ubound = (lbound + increment) * multiply
            assert(ubound > lbound)
        }

        print("Ran", testSizes.count, "equivalence tests on behalf of", caller,
              "with vectors and arrays of size", testSizes)

        XCTAssertGreaterThan(testSizes.reduce(0, +), 0)
    }
}

class VectorTest: XCTestCase {

    func testConj() {
        
        let empty = PersistentVector<Int>()
        XCTAssertEqual(0, empty.count)
        
        let seq = empty.conj(0).conj(1).conj(3)
        XCTAssertEqual(3, seq.count)
        
        XCTAssertEqual("[0, 1, 3]", seq.description)
    }
    
    func testConjRandomized() {
        let el1 = Randomized.element()
        let el2 = Randomized.element()

        Randomized.assertEquivalent(
            transientUpdate: { $0.conj(el1) },
            update: { $0.conj(el2) },
            equivalentArrayUpdate: { $0 += [el1, el2] })
    }

    func testPop() {
        let empty = PersistentVector<Int>()
        XCTAssertEqual(0, empty.count)
        
        let seq = empty.conj(0).conj(1).conj(3)
        XCTAssertEqual(3, seq.count)
    
        let smallerSeq = seq.pop()
    
        XCTAssertEqual("[0, 1]", smallerSeq.description)
    }
    
    func testPopRandomized() {
        Randomized.assertEquivalent(
            transientUpdate: { $0.pop()  },
            update: { $0.pop() },
            equivalentArrayUpdate: { arr in
                arr.removeLast()
                arr.removeLast() },
            minimumSize: 2)
    }
    
    func testAssoc() {
        
        let seq : PersistentVector<Int> = [0,1,3]
        
        let changedSeq = seq
            .assoc(index: 0, 42) // replace existing element
            .assoc(index: 3, 9000) // append new element
        
        XCTAssertEqual("[42, 1, 3, 9000]", changedSeq.description)
        XCTAssertEqual("[0, 1, 3]", seq.description)
    }
    
    func testAssocRandomized() {
        let el1 = Randomized.element()
        let el2 = Randomized.element()
        
        var idx1: Int!
        var idx2: Int!
        
        Randomized.assertEquivalent(
            initWithSize: { size in
                idx1 = Randomized.index(forSize: size)
                idx2 = Randomized.index(forSize: size) },
            transientUpdate: { $0.assoc(index: idx1, el1) },
            update: { $0.assoc(index: idx2, el2) },
            equivalentArrayUpdate: { arr in
                arr[idx1] = el1
                arr[idx2] = el2 },
            minimumSize: 2)
    }
    
    func testCollection() {
        
        let seq : PersistentVector<Float> = [0,1,3]
        
        XCTAssertEqual(0, seq[0], "subscript")
        XCTAssertEqual(1, seq[1], "subscript")
        XCTAssertEqual(3, seq[2], "subscript")
        
        func f(_ x: Int) -> Float {
            return sqrtf(Float(x))
        }
        
        let size = Int(UInt16.max)
        let empty: PersistentVector<Float> = []
        var tvec = TransientVector(vector: empty)
        for i in 0 ..< size {
            tvec = tvec.conj(f(i))
        }
        let vec = tvec.persistent()
        
        for i in (0 ..< size).reversed() {
            XCTAssertEqual(f(i), vec[i])
        }
    }
    
    func testCompare() {
        let seqA : PersistentVector<Int> = [0,1,2,3,5,6]
        
        let seqB = PersistentVector<Int>().conj(0).conj(1).conj(2).conj(3).conj(5).conj(6)
        
        XCTAssert(seqA == seqB)
        XCTAssert(seqA == seqA)
        XCTAssert(seqA != seqA.conj(7))
        XCTAssert(seqA != seqA.assoc(index: 1, 9000))
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
        
        let sum = seq.reduce(0,+)
        XCTAssertEqual(3524577, sum)
        
        let seq2 = seq.assoc(index: 30, 0)
        let sum2 = seq2.reduce(0,+)
        XCTAssertEqual(2692537, sum2)
        
        let sum3 = seq.reduce(0,+)
        XCTAssertEqual(3524577, sum3)
        
    }
    
    func testSubVectorRandomized() {
        var range: CountableClosedRange<Int>!
        
        Randomized.assertEquivalent(
            initWithSize: { size in
                let idx1 = Randomized.index(forSize: size)
                let idx2 = Randomized.index(forSize: size)
                range = min(idx1, idx2) ... max(idx1, idx2) },
            update: { PersistentVector($0[range]) },
            equivalentArrayUpdate: { arr in
                let subArray = arr[range]
                arr = Array(subArray) },
            minimumSize: 1)
    }

    func testConcat() {
        let v1 : PersistentVector<Int> = [2, 3, 4, 5]
        let v2 : PersistentVector<Int> = [20, 30, 40, 50]
        XCTAssertEqual(v1.concat(v2), [2, 3, 4, 5, 20, 30, 40, 50])
        XCTAssertEqual(PersistentVector(v1[1...2].concat(v2[1...2])), [3, 4, 30, 40])
    }
}
