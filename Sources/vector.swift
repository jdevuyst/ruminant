//
//  vector_impl.swift
//  RUMINANT – Swift persistent data structures à la Clojure
//
//  Created by Jonas De Vuyst on 18/02/15.
//  Copyright (c) 2015 Jonas De Vuyst. All rights reserved.
//
//  REFERENCES
//  http://blog.higher-order.net/2009/02/01/understanding-clojures-persistentvector-implementation.html
//  http://hypirion.com/musings/understanding-persistent-vector-pt-1
//  http://hypirion.com/musings/understanding-persistent-vector-pt-2
//  http://hypirion.com/musings/understanding-persistent-vector-pt-3
//  http://hypirion.com/musings/understanding-clojure-transients
//  http://hypirion.com/musings/persistent-vector-performance
//  http://www.mattgreer.org/articles/clojurescript-internals-vectors/
//  https://github.com/clojure/clojurescript/blob/22dd4fbeed72398cbc3336fccffe8196c56cd209/src/cljs/cljs/core.cljs#L4070
//

fileprivate final class LazyValue<T> {
    private var cachedValue: T?

    func cached(_ newValue: () -> T) -> T {
        if let x = cachedValue {
            return x
        } else {
            let x = newValue()
            cachedValue = x
            return x
        }
    }
}

fileprivate protocol CachableSeqHashValue : Sequence where Element: Hashable {
    var cachedHashValue: LazyValue<Int> { get }
}

public protocol PersistentVectorType: Hashable, Collection {
    var count: Int { get }
    
    func conj(_ element: Element) -> Self
    
    func pop() -> Self
    
    subscript(index: Int) -> Element { get }
    
    func assoc(index: Int, _ element: Element) -> Self

    func concat<Other: Sequence>(_ rhs: Other) -> Self where Other.Element == Element
}

public func ==<T: PersistentVectorType, U: PersistentVectorType>(lhs: T, rhs: U) -> Bool
    where T.Iterator.Element == U.Iterator.Element, T.Iterator.Element: Equatable
{
    guard lhs.count == rhs.count && lhs.hashValue == rhs.hashValue else {
        return false
    }

    return zip(lhs, rhs).allSatisfy({(x, y) in x == y})
}

//
//  MARK: - PersistentVector
//

public struct PersistentVector<T: Hashable> : PersistentVectorType, ExpressibleByArrayLiteral, CachableSeqHashValue {
    
    public typealias Iterator = ChunkedIterator<T>
    public typealias Index = Int
    public typealias SubSequence = Subvec<T>
    
    public let count: Int
    let shift: Int
    let root: Node<T>
    let tail: [T]

    fileprivate let cachedHashValue = LazyValue<Int>()
    
    internal init(count: Int, shift: Int, root: Node<T>, tail: [T]) {
        assert(count >= 0)
        assert(shift > 0)
        assert(shift % 5 == 0)
        self.count = count
        self.shift = shift
        self.root = root
        self.tail = tail
    }
    
    public init() {
        self.init(count: 0, shift: 5, root: TreeNode<T>(transientID: 0), tail: [])
    }
    
    public init(arrayLiteral xs: T...) {
        var v = PersistentVector()
        for x in xs {
            v = v.conj(x)
        }
        self.init(count: v.count, shift: v.shift, root: v.root, tail: v.tail)
    }
    
    public init<S : Sequence>(_ seq: S)  where S.Element == Element
    {
        let v = seq.reduce(PersistentVector()) { (accu, current) in accu.conj(current) }
        self.init(count: v.count, shift: v.shift, root: v.root, tail: v.tail)
    }
    
    private func tailOffset() -> Int {
        let r = count < 32 ? 0 : (((count - 1) >> 5) << 5)
        assert(r == count - tail.count)
        return r
    }
    
    private func verifyBounds(index: Int) {
        precondition(index >= 0 && index < count, "Index \(index) is out of bounds for vector of size \(count)")
    }
    
    internal func getChunk(index: Index) -> (chunk: [T], offset: Int) {
        let chunk = index < tailOffset() ? root.getChunk(index, shift: self.shift) : tail
        return (chunk: chunk, offset: index & 0x01f)
    }
    
    public func conj(_ element: T) -> PersistentVector {
        var newShift = shift
        let newRoot: Node<T>
        let newTail: [T]
        
        if count - tailOffset() < 32 {
            newRoot = root
            newTail = arrayConj(tail, val: element)
        } else {
            let tailNode = LeafNode<T>(transientID: 0, children: tail)
            let rootOverflow = (count >> 5) > (1 << shift)
            
            if rootOverflow {
                newShift += 5
                newRoot = TreeNode(transientID: 0, children: [root, tailNode.newPath(0, shift: shift)])
            } else {
                newRoot = root.pushTail(count, shift: shift, tailNode: tailNode)
            }
            
            newTail = [element]
        }
        
        return PersistentVector(count: count + 1, shift: newShift, root: newRoot, tail: newTail)
    }
    
    public func pop() -> PersistentVector {
        switch count {
        case 0:
            preconditionFailure("Cannot pop() an empty vector")
        case 1:
            return PersistentVector()
        case _ where count - tailOffset() > 1:
            return PersistentVector(count: count - 1, shift: shift, root: root, tail: arrayPop(tail))
        default:
            assert(count - 2 < tailOffset())
            let newTail = root.getChunk(count - 2, shift: shift)
            var newShift = shift
            let newRoot: Node<T>
            if let r = root.popTail(count, shift: shift) {
                if let r2 = r.onlyChildNode(), shift > 5 {
                    newShift -= 5
                    newRoot = r2
                } else {
                    newRoot = r
                }
            } else {
                assert(shift == 5)
                newRoot = TreeNode(transientID: 0)
            }
            return PersistentVector(count: count - 1, shift: newShift, root: newRoot, tail: newTail)
        }
    }
    
    public subscript(index: Index) -> T {
        verifyBounds(index: index)
        let t = getChunk(index: index)
        return t.chunk[t.offset]
    }
    
    public subscript(bounds: Range<Index>) -> SubSequence {
        return Subvec(vector: self, start: bounds.lowerBound, end: bounds.upperBound)
    }
    
    public func assoc(index: Index, _ element: T) -> PersistentVector {
        if index == count {
            return self.conj(element)
        }
        
        verifyBounds(index: index)
        
        if tailOffset() <= index {
            var newTail = tail
            newTail[index & 0x01f] = element
            return PersistentVector(count: count, shift: shift, root: root, tail: newTail)
        }
        
        let newRoot = root.assoc(index, shift: shift, element: element)
        return PersistentVector(count: count, shift: shift, root: newRoot, tail: tail)
    }
    
    public func makeIterator() -> Iterator {
        return ChunkedIterator(f: {self.getChunk(index: $0)}, start: 0, end: count)
    }
    
    public func transient() -> TransientVector<T> {
        return TransientVector(vector: self)
    }

    public func concat<Other: Sequence>(_ rhs: Other) -> PersistentVector where Other.Element == T {
        var v = transient()
        v = v.concat(rhs)
        return v.persistent()
    }
}

//
//  MARK: - Subvec
//

public struct Subvec<T: Hashable>: PersistentVectorType, CachableSeqHashValue {
    public typealias Index = Int
    public typealias Iterator = ChunkedIterator<T>
    public typealias SubSequence = Subvec<T>
    
    private let v: PersistentVector<T>
    private let start: Index
    private let end: Index

    fileprivate let cachedHashValue = LazyValue<Int>()
    
    init(vector: PersistentVector<T>, start: Index, end: Index) {
        precondition(end >= start)
        precondition(end - start <= vector.count)
        self.v = vector
        self.start = start
        self.end = end
    }
    
    init(vector: Subvec, start: Index, end: Index) {
        precondition(end >= start)
        precondition(end - start <= vector.count)
        self.v = vector.v
        self.start = vector.start + start
        self.end = vector.start + end
    }
    
    public var count: Int { return end - start }
    
    public func conj(_ element: T) -> SubSequence {
        return Subvec(vector: v.assoc(index: end, element), start: start, end: end + 1)
    }
    
    public func pop() -> SubSequence {
        precondition(count > 0, "Cannot pop() an empty vector")
        return Subvec(vector: v, start: start, end: end - 1)
    }
    
    public func assoc(index: Index, _ element: T) -> SubSequence {
        if index == count {
            return conj(element)
        } else {
            return Subvec(vector: v.assoc(index: index + start, element), start: start, end: end)
        }
    }
    
    public subscript(index: Index) -> T { return v[index + start] }
    
    public subscript(bounds: Range<Index>) -> SubSequence {
        return Subvec(vector: self, start: bounds.lowerBound, end: bounds.upperBound)
    }
    
    public func makeIterator() -> Iterator {
        return ChunkedIterator<T>(f: {self.v.getChunk(index: $0)}, start: start, end: end)
    }

    public func concat<Other: Sequence>(_ rhs: Other) -> Subvec where Other.Element == Element {
        return rhs.reduce(self) { $0.conj($1) }
    }
}

//
//  MARK: - TransientVector
//

private var transientVectorCounter = 0

public struct TransientVector<T: Hashable> {
    public typealias Element = T
    public typealias Index = Int
    
    public var count: Int
    private var shift: Int
    private var root: Node<T>
    private var tail: [T]
    
    private init(count: Int, shift: Int, root: Node<T>, tail: [T]) {
        assert(count >= 0)
        assert(shift > 0)
        assert(shift % 5 == 0)
        assert(root.editID != 0)
        
        self.count = count
        self.shift = shift
        self.root = root
        
        self.tail = []
        self.tail.reserveCapacity(32)
        self.tail.append(contentsOf: tail)
    }
    
    private init() {
        transientVectorCounter += 1
        self.init(count: 0, shift: 5, root: TreeNode(transientID: transientVectorCounter, children: []), tail: [])
    }
    
    init(vector: PersistentVector<T>) {
        transientVectorCounter += 1
        self.init(count: vector.count, shift: vector.shift, root: vector.root.transientVersion(transientVectorCounter), tail: vector.tail)
    }
    
    private func tailOffset() -> Int {
        let r = count < 32 ? 0 : (((count - 1) >> 5) << 5)
        assert(r == count - tail.count)
        return r
    }
    
    private func verifyBounds(index: Int) {
        precondition(index >= 0 && index < count, "Index \(index) is out of bounds for vector of size \(count)")
    }
    
    private func verifyTransient() {
        precondition(root.editID != 0, "Cannot modify TransientVector after persistent()")
        assert(tail.capacity == 32)
    }
    
    private func transientChunk(index: Int,  chunk: inout [T]) {
        chunk = index < tailOffset() ? root.getChunk(index, shift: self.shift) : tail
    }
    
    internal func getChunk(index: Index) -> (chunk: [T], offset: Int) {
        let chunk = index < tailOffset() ? root.getChunk(index, shift: self.shift) : tail
        return (chunk: chunk, offset: index & 0x01f)
    }
    
    public mutating func conj(_ element: T) -> TransientVector {
        verifyTransient()
        
        if count - tailOffset() < 32 {
            tail.append(element)
        } else {
            let tailNode = LeafNode<T>(transientID: root.editID, children: tail)
            
            tail = []
            tail.reserveCapacity(32)
            tail.append(element)
            
            if count >> 5 > 1 << shift {
                root = TreeNode<T>(transientID: root.editID, children: [root, tailNode.newPath(root.editID, shift: shift)])
                shift += 5
            } else {
                root = root.transientPushTail(root.editID, count: count, shift: shift, tailNode: tailNode)
            }
        }
        
        count += 1
        return self
    }
    
    public mutating func persistent() -> PersistentVector<T> {
        verifyTransient()
        
        root.editID = 0
        
        var newTail = [T]()
        newTail.reserveCapacity(tail.count)
        newTail.append(contentsOf: tail)
        
        return PersistentVector<T>(count: count, shift: shift, root: root, tail: newTail)
    }
    
    public mutating func pop() -> TransientVector {
        verifyTransient()
        
        switch count {
        case 0:
            preconditionFailure("Cannot pop() an empty vector")
        case 1:
            return TransientVector()
        case _ where count - tailOffset() > 1:
            tail.removeLast()
        default:
            assert(count - 2 < tailOffset())
            
            transientChunk(index: count - 2, chunk: &tail)
            
            if let r = root.transientPopTail(root.editID, count: count, shift: shift) {
                if let r2 = r.onlyChildNode(), shift > 5 {
                    shift -= 5
                    root = r2
                } else {
                    root = r
                }
            } else {
                assert(shift == 5)
                root = TreeNode(transientID: root.editID)
            }
        }
        
        count -= 1
        return self
    }
    
    public mutating func assoc(index: Int, _ element: T) -> TransientVector {
        verifyTransient()
        
        if index == count {
            return self.conj(element)
        }
        
        verifyBounds(index: index)
        
        if tailOffset() <= index {
            tail[index &  0x01f] = element
        } else {
            root = root.transientAssoc(root.editID, index: index, shift: shift, element: element)
        }
        
        return self
    }
    
    public var startIndex: Index { return 0 }
    
    public subscript(index: Index) -> T {
        verifyBounds(index: index)
        let t = getChunk(index: index)
        return t.chunk[t.offset]
    }

    public mutating func concat<Other: Sequence>(_ rhs: Other) -> TransientVector where Other.Element == T {
        return rhs.reduce(into: self) { $0 = $0.conj($1) }
    }
}

//
//  MARK: - Extensions
//

extension CachableSeqHashValue {
    public func hash(into hasher: inout Hasher) {
        for x in self {
            hasher.combine(x)
        }
    }

    public var hashValue: Int {
        return cachedHashValue.cached {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
        }
    }
}

extension PersistentVector : CustomStringConvertible, CustomDebugStringConvertible
{
    public var description: String { return seqDescription(xs: self, ldelim: "[", rdelim: "]") }
    
    public var debugDescription: String { return seqDebugDescription(xs: self, ldelim: "[", rdelim: "]") }
}

extension PersistentVector : Collection
{
    public var startIndex: Index { return 0 }
    
    public var endIndex: Index { return self.count }
    
    public func index(after i: Index) -> Index {
        assert( i < endIndex)
        return i + 1
    }
}

extension Subvec : CustomStringConvertible, CustomDebugStringConvertible
{
    public var description: String { return seqDescription(xs: self, ldelim: "[", rdelim: "]") }
    
    public var debugDescription: String { return seqDebugDescription(xs: self, ldelim: "[", rdelim: "]") }
}

extension Subvec : Collection
{
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.count }
    
    public func index(after i: Index) -> Index {
        assert( i < endIndex)
        return i + 1
    }
}

