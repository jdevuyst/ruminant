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

enum Op<T> {
    typealias Element = T

    case conj(T)
    case pop
    case assoc(Int, T)
    case concat([T])
}

extension Op: Arbitrary where Element: Arbitrary {
    typealias GenType = Gen<Op<Element>>

    static var arbitrary: GenType {
        Int.arbitrary.suchThat({$0 >= 0}).flatMap(Self.arbitrary(forSize:))
    }

    static func arbitrary(forSize size: Int) -> GenType {
        let conjOp: GenType =
            T.arbitrary.map { .conj($0) }
        let popOp: GenType? =
            size > 0 ? Gen.pure(.pop) : nil
        let assocOp: GenType =
            Gen.zip(Gen.choose((0, size)), Element.arbitrary).map{ .assoc($0, $1) }
        let concatOp: GenType =
            [T].arbitrary.map { .concat($0) }
        let ops = [(1, conjOp), (3, popOp), (5, assocOp), (1, concatOp)]
        return Gen.frequency(ops.compactMap {
            switch $0 {
            case let (n, .some(op)): return .some((n, op))
            case (_, .none): return .none
            }
        })
    }

    static func arbitraryList(forSize origSize: Int) -> Gen<[Op<Element>]> {
        Gen.sized { n in
            func next(size: Int, ops: [Op<Element>]) -> Gen<(Int, [Op<Element>])> {
                return Self.arbitrary(forSize: size).map { op in
                    let newSize: Int
                    switch op {
                    case .pop: newSize = size - 1
                    default: newSize = size
                    }
                    return (newSize, ops + [op])
                }
            }

            var gen: Gen<(Int, [Op<Element>])> = Gen.pure((origSize, []))
            for _ in 0 ..< n {
                gen = gen.flatMap { (size, ops) in
                    return next(size: size, ops: ops)
                }
            }

            return gen.map {$0.1}
        }
    }
}

protocol CanApplyOp {
    associatedtype Element

    mutating func apply(op: Op<Element>) -> Self
}

extension CanApplyOp {
    mutating func applyAll(ops: [Op<Element>]) -> Self {
        for op in ops {
            self = self.apply(op: op)
        }
        return self
    }
}

extension PersistentVector: CanApplyOp {
    func apply(op: Op<T>) -> PersistentVector<T> {
        switch op {
        case let .conj(x): return conj(x)
        case .pop: return pop()
        case let .assoc(idx, x): return assoc(index: idx, x)
        case let .concat(xs): return concat(xs)
        }
    }
}

extension Subvec: CanApplyOp {
    func apply(op: Op<T>) -> Subvec<T> {
        switch op {
        case let .conj(x): return conj(x)
        case .pop: return pop()
        case let .assoc(idx, x): return assoc(index: idx, x)
        case let .concat(xs): return concat(xs)
        }
    }
}

extension TransientVector: CanApplyOp {
    mutating func apply(op: Op<T>) -> TransientVector<T> {
        switch op {
        case let .conj(x): return conj(x)
        case .pop: return pop()
        case let .assoc(idx, x): return assoc(index: idx, x)
        case let .concat(xs): return concat(xs)
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

        property(name + " == implies identical hash value") <- forAll { (xs: T, ys: T) in
            return xs != ys || xs.hashValue == ys.hashValue
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

        property(name + " concat([]) is a no-op") <- forAll { (xs: T) in
            return xs.concat([]) == xs
        }

        property(name + " xs.concat([y]) == xs.conj(y)") <- forAll { (xs: T, y: T.Element) in
            return xs.concat([y]) == xs.conj(y)
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
    typealias ElementType = Int

    func testPersistentVectorType() {
        PersistentVectorTypeTests<PersistentVector<ElementType>>(name: "PersistentVector").testAll()
        PersistentVectorTypeTests<Subvec<ElementType>>(name: "Subvec").testAll()
    }

    func testToAndFromArray() {
        property("To-array after from-array is a no-op") <- forAll { (xs: [ElementType]) in
            return xs == Array(PersistentVector(xs))
        }
    }

    func testManyOps() {
        property("All vector types behave alike") <- forAll { (subvec: Subvec<ElementType>) in
            return forAll(Op<ElementType>.arbitraryList(forSize: subvec.count)) { ops in
                var persistent = PersistentVector(subvec)
                var subvec = subvec
                var transient = persistent.transient()
                persistent = persistent.applyAll(ops: ops)
                subvec = subvec.applyAll(ops: ops)
                transient = transient.applyAll(ops: ops)
                return
                    (persistent == transient.persistent()) <?> "Transient"
                    ^&&^
                    (persistent == subvec && persistent.hashValue == subvec.hashValue) <?> "Subvec"
            }
        }
    }
}
