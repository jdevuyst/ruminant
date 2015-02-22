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

//
//  MARK: - ChunkedGenerator
//

// n.b. ChunkedGenerator copies can be advanced independently
public struct ChunkedGenerator<T>: GeneratorType {
    typealias Element = T
    typealias ChunkFunction = Int -> (chunk: [T], offset: Int)
    
    private let f: ChunkFunction
    private let end: Int
    private var i: Int
    private var j = 0
    private var chunk: [T]
    
    init(f: ChunkFunction, start: Int, end: Int) {
        assert(end >= start)
        self.f = f
        self.i = start
        self.end = end
        (chunk: self.chunk, offset: self.j) = end - start == 0 ? ([], 0) : f(start)
    }
    
    public mutating func next() -> T? {
        if i < end {
            if j == chunk.count {
                (chunk: chunk, offset: j) = f(0)
            }
            
            i++
            return chunk[j++]
        }
        
        return nil
    }
}

//
//  MARK: - Node Types
//

private class Node<T> {
    let transient: Bool
    
    init(transient: Bool) {
        self.transient = transient
    }
    
    func newPath(#transient: Bool, shift: Int) -> Node<T> {
        return shift == 0
            ? self
            : TreeNode(transient: transient, children: [self])
                .newPath(transient: transient, shift: shift - 5)
    }
    
    func pushTail(#count: Int, shift: Int, tailNode: Node<T>) -> Node<T> { assert(false) }
    
    func popTail(#count: Int, shift: Int) -> Node<T>? { assert(false) }
    
    func getChunk(#index: Int, shift: Int) -> [T] { assert(false) }
    
    func assoc(#index: Int, shift: Int, element: T) -> Node<T> { assert(false) }
    
    func onlyChildNode() -> Node<T>? { assert(false) }
}

private class TreeNode<T> : Node<T> {
    private let children: [Node<T>]
    
    init(transient: Bool, children: [Node<T>]) {
        assert(children.count <= 32)
        self.children = children
        super.init(transient: transient)
    }
    
    convenience init() {
        self.init(transient: false, children: [])
    }
    
    override func pushTail(#count: Int, shift: Int, tailNode: Node<T>) -> Node<T> {
        assert(shift > 0)
        let subidx = ((count - 1) >> shift) & 0x01f
        assert(subidx < 32)
        
        let newChildren: [Node<T>]
        
        if(shift == 5) {
            assert(subidx == children.count)
            newChildren = arrayConj(children, tailNode)
        } else if subidx == children.count {
            newChildren = arrayConj(children, tailNode.newPath(transient: false, shift: shift - 5))
        } else {
            assert(subidx < children.count)
            newChildren = arrayAssoc(children, subidx, children[subidx].pushTail(count: count, shift: shift - 5, tailNode: tailNode))
        }
        
        return TreeNode(transient: transient, children: newChildren)
    }
    
    override func popTail(#count: Int, shift: Int) -> Node<T>? {
        let subidx = ((count - 2) >> shift) & 0x01f
        assert(subidx < 32)
        
        if shift > 5 {
            if let newChild = children[subidx].popTail(count: count, shift: shift - 5) {
                assert(subidx < children.count)
                return TreeNode(transient: transient, children: arrayAssoc(children, subidx, newChild))
            }
        }
        
        assert(subidx == children.count - 1)
        return subidx == 0 ? nil : TreeNode(transient: transient, children: arrayPop(children))
    }
    
    override func getChunk(#index: Int, shift: Int) -> [T] {
        assert(shift > 0)
        return children[(index >> shift) & 0x01f].getChunk(index: index, shift: shift - 5)
    }
    
    override func assoc(#index: Int, shift: Int, element: T) -> Node<T> {
        let subidx = (index >> shift) & 0x01f
        assert(subidx < 32)
        
        assert(shift > 0)
        assert(subidx < children.count)
        let newChildren = arrayAssoc(children, subidx, children[subidx].assoc(index: index, shift: shift - 5, element: element))
        return TreeNode(transient: transient, children: newChildren)
    }
    
    override func onlyChildNode() -> Node<T>? {
        return children.count == 1 ? children[0] : nil
    }
}

private class LeafNode<T> : Node<T> {
    private let children: [T]
    
    init(transient: Bool, children: [T]) {
        assert(!children.isEmpty)
        assert(children.count <= 32)
        self.children = children
        super.init(transient: transient)
    }
    
    override func getChunk(#index: Int, shift: Int) -> [T] {
        assert(shift == 0)
        return children
    }
    
    override func assoc(#index: Int, shift: Int, element: T) -> Node<T> {
        let subidx = (index >> shift) & 0x01f
        assert(subidx < 32)
        
        assert(shift == 0)
        assert(subidx < children.count)
        return LeafNode(transient: transient, children: arrayAssoc(children, subidx, element))
    }
}

//
//  MARK: - PersistentVectorType
//

public protocol PersistentVectorType: Hashable, SequenceType {
    var count: Int { get }
    
    func conj(element: Generator.Element) -> Self

    func pop() -> Self

    subscript(index: Int) -> Generator.Element { get }

    func assoc(index: Int, _ element: Generator.Element) -> Self
}

public func ==<T: PersistentVectorType, U: PersistentVectorType where T.Generator.Element == U.Generator.Element, T.Generator.Element: Equatable>(lhs: T, rhs: U) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    
    var lg = lhs.generate()
    var rg = rhs.generate()
    while let x = lg.next() {
        if x != rg.next()! {
            return false
        }
    }
    
    return true
}

//
//  MARK: - PersistentVector
//

public struct PersistentVector<T: Hashable> : PersistentVectorType, ArrayLiteralConvertible {
    public let count: Int
    private let shift: Int
    private let root: Node<T>
    private let tail: [T]
    private let hashBox = LazyBox<Int>()
    
    private init(count: Int, shift: Int, root: Node<T>, tail: [T]) {
        assert(count >= 0)
        assert(shift > 0)
        assert(shift % 5 == 0)
        self.count = count
        self.shift = shift
        self.root = root
        self.tail = tail
    }
    
    public init() {
        self.init(count: 0, shift: 5, root: TreeNode(), tail: [])
    }
    
    public init(arrayLiteral xs: T...) {
        var v = PersistentVector()
        for x in xs {
            v = v.conj(x)
        }
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
    
    private func getChunk(index: Int) -> (chunk: [T], offset: Int) {
        let chunk = index < tailOffset() ? root.getChunk(index: index, shift: self.shift) : tail
        return (chunk: chunk, offset: index & 0x01f)
    }
    
    public func conj(element: T) -> PersistentVector {
        var newShift = shift
        let newRoot: Node<T>
        let newTail: [T]
        
        if count - tailOffset() < 32 {
            newRoot = root
            newTail = arrayConj(tail, element)
        } else {
            let tailNode = LeafNode<T>(transient: false, children: tail)
            let rootOverflow = (count >> 5) > (1 << shift)
            
            if rootOverflow {
                newShift += 5
                newRoot = TreeNode(transient: false, children: [root, tailNode.newPath(transient: false, shift: shift)])
            } else {
                newRoot = root.pushTail(count: count, shift: shift, tailNode: tailNode)
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
            let newTail = root.getChunk(index: count - 2, shift: shift)
            var newShift = shift
            let newRoot: Node<T>
            if let r = root.popTail(count: count, shift: shift) {
                if let r2 = r.onlyChildNode() where shift > 5 {
                    newShift -= 5
                    newRoot = r2
                } else {
                    newRoot = r
                }
            } else {
                assert(shift == 5)
                newRoot = TreeNode(transient: false, children: [])
            }
            return PersistentVector(count: count - 1, shift: newShift, root: newRoot, tail: newTail)
        }
    }
    
    public subscript(index: Int) -> T {
        verifyBounds(index)
        let t = getChunk(index)
        return t.chunk[t.offset]
    }
    
    public func assoc(index: Int, _ element: T) -> PersistentVector {
        if index == count {
            return self.conj(element)
        }
        
        verifyBounds(index)
        
        if tailOffset() <= index {
            var newTail = tail
            newTail[index & 0x01f] = element
            return PersistentVector(count: count, shift: shift, root: root, tail: newTail)
        }
        
        let newRoot = root.assoc(index: index, shift: shift, element: element)
        return PersistentVector(count: count, shift: shift, root: newRoot, tail: tail)
    }
    
    public func generate() -> ChunkedGenerator<T> {
        return ChunkedGenerator(f: {self.getChunk($0)}, start: 0, end: count)
    }
    
    public var hashValue: Int { return count }
}

//
//  MARK: - Subvec
//

public struct Subvec<T: Hashable>: PersistentVectorType {
    private let v: PersistentVector<T>
    private let start: Int
    private let end: Int
    private let hashBox = LazyBox<Int>()
    
    init(vector: PersistentVector<T>, start: Int, end: Int) {
        self.v = vector
        self.start = start
        self.end = end
    }
    
    init(vector: Subvec, start: Int, end: Int) {
        self.v = vector.v
        self.start = vector.start + start
        self.end = vector.start + end
    }
    
    public var count: Int { return end - start }
    
    public func conj(element: T) -> Subvec {
        return Subvec(vector: v.assoc(end, element), start: start, end: end + 1)
    }
    
    public func pop() -> Subvec {
        return Subvec(vector: v, start: start, end: end - 1)
    }
    
    public subscript(index: Int) -> T { return v[index + start] }
    
    public func assoc(index: Int, _ element: T) -> Subvec {
        return Subvec(vector: v.assoc(index + start, element), start: start, end: end)
    }
    
    public func generate() -> ChunkedGenerator<T> {
        return ChunkedGenerator(f: {self.v.getChunk($0)}, start: start, end: end)
    }
    
    public var hashValue: Int { return count }
}

//
//  MARK: - Extensions
//

extension PersistentVector : Printable, DebugPrintable, CollectionType, Sliceable {
    public var description: String { return seqDescription(self, "[", "]") }
    public var debugDescription: String { return seqDebugDescription(self, "[", "]") }
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return self.count }
    public subscript(bounds: Range<Int>) -> Subvec<T> {
        return Subvec(vector: self, start: bounds.startIndex, end: bounds.endIndex)
    }
}

extension Subvec : Printable, DebugPrintable, CollectionType, Sliceable {
    public var description: String { return seqDescription(self, "[", "]") }
    public var debugDescription: String { return seqDebugDescription(self, "[", "]") }
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return self.count }
    public subscript(bounds: Range<Int>) -> Subvec<T> {
        return Subvec(vector: self, start: bounds.startIndex, end: bounds.endIndex)
    }
}