//
//  quickCheckTests.swift
//  ruminantTests
//
//  Created by Jonas De Vuyst on 18/4/20.
//

import XCTest
@testable import SwiftCheck
@testable import ruminant

extension PersistentVector: Arbitrary where Element: Arbitrary {
    public static var arbitrary: Gen<Self> {
        return Array.arbitrary.map(Self.init)
    }
}

extension Subvec: Arbitrary where Element: Arbitrary {
    public static var arbitrary: Gen<Self> {
        return Gen
            .zip(PersistentVector.arbitrary, Int.arbitrary, Int.arbitrary)
            .suchThat { (v, l, u) in l >= 0 && l <= u && u < v.count }
            .map(Self.init)
    }
}

extension TransientVector: Arbitrary where Element: Arbitrary {
    public static var arbitrary: Gen<Self> {
        return PersistentVector.arbitrary.map(Self.init)
    }
}

extension Collection where Index: Arbitrary, Index: Hashable {
    var arbitraryPartition: Gen<[SubSequence]> {
        if isEmpty {
            let subseq = self[startIndex..<endIndex]
            return Gen.pure([subseq])
        }

        return Gen<Index>.fromInitialSegments(of: indices.shuffled())
            .map { [startIndex, endIndex] cuts in
                Array(Set([startIndex, endIndex] + cuts)).sorted()
            }.map { cuts in
                return zip(cuts.dropLast(), cuts.dropFirst()).map { (l, u) in
                    return self[l..<u]
                }
        }
    }
}

class PersistentVectorTypeTests<T> where T: PersistentVectorType, T: Arbitrary, T.Element: Arbitrary, T.Element: Hashable, T.SubSequence: PersistentVectorType, T.Index == Int {
    let name: String

    init(name: String) {
        self.name = name
    }

    func testEquality() {
        property(name + " == is an equivalence relation") <- (
            (forAll { (xs: T) in xs == xs }) <?> "Reflexivity"
            ^&&^
            (forAll { (xs: T, ys: T) in (xs == ys) == (ys == xs) }) <?> "Symmetry"
            ^&&^
            (forAll { (xs: T, ys: T, zs: T) in !(xs == ys && ys == zs) || (xs == zs) }) <?> "Transitivity"
         )

        property(name + " == uses value equality") <- forAll { (xs: T, ys: T) in
            return (Array(xs) == Array(ys)) == (xs == ys)
        }
    }

    func testGet() {
        property(name + " has consistent indices") <- forAll { (xs: T) in
            return Array(xs) == (0 ..< xs.count).map {xs[$0]}
        }
    }

    func testAssoc() {
        property(name + " assoc() sets elements")
            <- forAll(T.arbitrary.suchThat({$0.count > 0})) { xs in
                return forAll(Gen<Int>.fromElements(in: 0 ... xs.count - 1)) { i in
                    return forAll { (y: T.Element) in
                        let prev = xs[i]
                        let new = xs.assoc(index: i, y)
                        return
                            (new[i] == y) <?> "Set value"
                            ^&&^
                            (new.assoc(index: i, prev) == xs) <?> "Unset value"
                    }
                }
        }
    }

    func testConjPop() {
        property(name + " conj() appends") <- forAll { (xs: T, y: T.Element) in
            return xs.conj(y)[xs.count] == y
        }

        property(name + " pop() after conj() is a no-op") <- forAll { (xs: T, y: T.Element) in
            return xs == xs.conj(y).pop()
        }
    }

    func testConjAssoc() {
        property(name + " assoc() can append elements") <- forAll { (xs: T, y: T.Element) in
            return xs.conj(y) == xs.assoc(index: xs.count, y)
        }
    }

    func testConcat() {
        property(name + " concat() concatenates vectors") <- forAll { (xs: T, ys: T) in
            return Array(xs) + Array(ys) == Array(xs.concat(ys))
        }
    }

    func testSubvec() {
        property("Taking Subvec of full PersistentVector preserves equality") <- forAll { (xs: T) in
            return xs == xs[0..<xs.count]
        }

        property("Converting a Subvec to a PersistentVector preserves equality") <- forAll { (xs: T) in
            return xs == PersistentVector(xs)
        }

        property("Concat of a Subvec partition is equal to the original vector") <- forAll { (xs: T) in
            func f(_ lhs: PersistentVector<T.Element>, _ rhs: T.SubSequence) -> PersistentVector<T.Element> {
                lhs.concat(rhs)
            }
            return xs.arbitraryPartition.map { xs == $0.reduce([], f) }
        }
    }

    func testAll() {
        testEquality()
        testGet()
        testAssoc()
        testConjPop()
        testConjAssoc()
        testConcat()
        testSubvec()
    }
}

class QuickCheckTest: XCTestCase {
    func testPersistentVectorType() {
        PersistentVectorTypeTests<PersistentVector<Int>>(name: "PersistentVector").testAll()
        PersistentVectorTypeTests<Subvec<Int>>(name: "Subvec").testAll()
    }

    func testToAndFromArray() {
        property("To-array after from-array is a no-op") <- forAll { (xs: [Int]) in
            return xs == Array(PersistentVector(xs))
        }
    }

    func testToAndFromTransient() {
        property("persistent() after transient() is a no-op") <- forAll { (xs: [Int]) in
            let v = PersistentVector(xs)
            var v2 = v.transient()
            return v == v2.persistent()
        }
    }
}
