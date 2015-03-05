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

// n.b. ChunkedGenerator copies can be advanced independently when backed by a persistent data structure
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

class Node<T> {
    var editID: Int
    
    init(transientID: Int) {
        self.editID = transientID
    }
    
    func transientVersion(#transientID: Int) -> Node { assert(false) }
    
    func getChunk(#index: Int, shift: Int) -> [T] { assert(false) }
    
    func transientChunk(#transientID: Int, index: Int, shift: Int, inout chunk: [T]) { assert(false) }
    
    func newPath(#transientID: Int, shift: Int) -> Node {
        return shift == 0
            ? self
            : TreeNode(transientID: transientID, children: [self])
                .newPath(transientID: transientID, shift: shift - 5)
    }
    
    func pushTail(#count: Int, shift: Int, tailNode: Node) -> Node { assert(false) }
    
    func transientPushTail(#transientID: Int, count: Int, shift: Int, tailNode: Node) -> Node { assert(false) }
    
    func popTail(#count: Int, shift: Int) -> Node? { assert(false) }
    
    func transientPopTail(#transientID: Int, count: Int, shift: Int) -> Node? { assert(false) }
    
    func assoc(#index: Int, shift: Int, element: T) -> Node { assert(false) }
    
    func transientAssoc(#transientID: Int, index: Int, shift: Int, element: T) -> Node { assert(false) }
    
    func onlyChildNode() -> Node? { assert(false) }
}

private class TreeNode<T> : Node<T> {
    private var children: [Node<T>]
    
    init(transientID: Int, children: [Node<T>]) {
        assert(children.count <= 32)
        assert(children.capacity <= 32)
        self.children = children
        super.init(transientID: transientID)
    }
    
    override init(transientID: Int) {
        self.children = []
        if transientID != 0 {
            self.children.reserveCapacity(32)
        }
        super.init(transientID: transientID)
    }
    
    override func transientVersion(#transientID: Int) -> TreeNode {
        if self.editID == transientID {
            return self
        }
        
        var newChildren = [Node<T>]()
        newChildren.reserveCapacity(32)
        newChildren.extend(children)
        return TreeNode<T>(transientID: transientID, children: newChildren)
    }
    
    override func getChunk(#index: Int, shift: Int) -> [T] {
        assert(shift > 0)
        return children[(index >> shift) & 0x01f].getChunk(index: index, shift: shift - 5)
    }
    
    override func transientChunk(#transientID: Int, index: Int, shift: Int, inout chunk: [T]) {
        assert(shift > 0)
        children[(index >> shift) & 0x01f].transientChunk(transientID: transientID, index: index, shift: shift - 5, chunk: &chunk)
    }
    
    override func pushTail(#count: Int, shift: Int, tailNode: Node<T>) -> Node<T> {
        assert(shift > 0)
        let subidx = ((count - 1) >> shift) & 0x01f
        
        let newChildren: [Node<T>]
        
        if(shift == 5) {
            assert(subidx == children.count)
            newChildren = arrayConj(children, tailNode)
        } else if subidx == children.count {
            newChildren = arrayConj(children, tailNode.newPath(transientID: 0, shift: shift - 5))
        } else {
            newChildren = arrayAssoc(children, subidx, children[subidx].pushTail(count: count, shift: shift - 5, tailNode: tailNode))
        }
        
        return TreeNode(transientID: self.editID, children: newChildren)
    }
    
    override func transientPushTail(#transientID: Int, count: Int, shift: Int, tailNode: Node<T>) -> Node<T> {
        assert(shift > 0)
        
        let transientSelf = self.transientVersion(transientID: transientID)
        let subidx = ((count - 1) >> shift) & 0x01f
        
        if(shift == 5) {
            assert(subidx == children.count)
            children.append(tailNode)
        } else if subidx == children.count {
            children.append(tailNode.newPath(transientID: transientID, shift: shift - 5))
        } else {
            children[subidx] = children[subidx].pushTail(count: count, shift: shift - 5, tailNode: tailNode)
        }
        
        return transientSelf
    }
    
    override func popTail(#count: Int, shift: Int) -> Node<T>? {
        let subidx = ((count - 2) >> shift) & 0x01f
        
        if shift > 5 {
            if let newChild = children[subidx].popTail(count: count, shift: shift - 5) {
                return TreeNode(transientID: self.editID, children: arrayAssoc(children, subidx, newChild))
            }
        }
        
        assert(subidx == children.count - 1)
        return subidx == 0 ? nil : TreeNode(transientID: self.editID, children: arrayPop(children))
    }
    
    override func transientPopTail(#transientID: Int, count: Int, shift: Int) -> Node<T>? {
        let subidx = ((count - 2) >> shift) & 0x01f
        
        if shift > 5 {
            if let newChild = children[subidx].transientPopTail(transientID: transientID, count: count, shift: shift - 5) {
                children[subidx] = newChild
                return self
            }
        }
        
        assert(subidx == children.count - 1)
        
        if subidx == 0 {
            return nil
        }
        
        children.removeLast()
        return self
    }
    
    override func assoc(#index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift > 0)
        let subidx = (index >> shift) & 0x01f
        let newChildren = arrayAssoc(children, subidx, children[subidx].assoc(index: index, shift: shift - 5, element: element))
        return TreeNode(transientID: self.editID, children: newChildren)
    }
    
    override func transientAssoc(#transientID: Int, index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift > 0)
        let subidx = (index >> shift) & 0x01f
        let transientSelf = transientVersion(transientID: transientID)
        transientSelf.children[subidx] = children[subidx].transientAssoc(transientID: transientID, index: index, shift: shift - 5, element: element)
        return transientSelf
    }
    
    override func onlyChildNode() -> Node<T>? {
        return children.count == 1 ? children[0] : nil
    }
}

private class LeafNode<T> : Node<T> {
    private var children: [T]
    
    init(transientID: Int, children: [T]) {
        assert(children.count == 32)
        assert(children.capacity == 32)
        self.children = children
        super.init(transientID: transientID)
    }
    
    override func transientVersion(#transientID: Int) -> LeafNode {
        assert(transientID != 0)
        return self.editID == transientID ? self : LeafNode<T>(transientID: transientID, children: children)
    }
    
    override func getChunk(#index: Int, shift: Int) -> [T] {
        assert(shift == 0)
        return children
    }
    
    override func transientChunk(#transientID: Int, index: Int, shift: Int, inout chunk: [T]) {
        assert(shift == 0)
        let transientSelf = transientVersion(transientID: transientID)
        chunk = transientSelf.children
    }
    
    override func assoc(#index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift == 0)
        let subidx = index & 0x01f
        return LeafNode(transientID: self.editID, children: arrayAssoc(children, subidx, element))
    }
    
    override func transientAssoc(#transientID: Int, index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift == 0)
        let subidx = index & 0x01f
        let transientSelf = transientVersion(transientID: transientID)
        transientSelf.children[subidx] = element
        return transientSelf
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
    
    var rg = rhs.generate()
    for x in lhs {
        if x != rg.next()! {
            return false
        }
    }
    
    return true
}

//
//  MARK: - PersistentVector
//

public struct PersistentVector<T: Equatable> : PersistentVectorType, ArrayLiteralConvertible {
    public let count: Int
    let shift: Int
    let root: Node<T>
    let tail: [T]
    
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
        self.init(count: 0, shift: 5, root: TreeNode(transientID: 0), tail: [])
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
            let tailNode = LeafNode<T>(transientID: 0, children: tail)
            let rootOverflow = (count >> 5) > (1 << shift)
            
            if rootOverflow {
                newShift += 5
                newRoot = TreeNode(transientID: 0, children: [root, tailNode.newPath(transientID: 0, shift: shift)])
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
                newRoot = TreeNode(transientID: 0)
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
    
    public func transient() -> TransientVector<T> {
        return TransientVector(vector: self, count: count)
    }
}

//
//  MARK: - Subvec
//

public struct Subvec<T: Equatable>: PersistentVectorType {
    private let v: PersistentVector<T>
    private let start: Int
    private let end: Int
    
    init(vector: PersistentVector<T>, start: Int, end: Int) {
        assert(end >= start)
//        assert(end - start <= vector.count)
        self.v = vector
        self.start = start
        self.end = end
    }
    
    init(vector: Subvec, start: Int, end: Int) {
        assert(end >= start)
//        assert(end - start <= vector.count)
        self.v = vector.v
        self.start = vector.start + start
        self.end = vector.start + end
    }
    
    public var count: Int { return end - start }
    
    public func conj(element: T) -> Subvec {
        return Subvec(vector: v.assoc(end, element), start: start, end: end + 1)
    }
    
    public func pop() -> Subvec {
        precondition(count > 0, "Cannot pop() an empty vector")
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
//  MARK: - TransientVector
//

private var transientVectorCounter = 0

public struct TransientVector<T: Equatable> {
    private var count: Int
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
        self.tail.extend(tail)
    }
    
    private init() {
        self.init(count: 0, shift: 5, root: TreeNode(transientID: ++transientVectorCounter, children: []), tail: [])
    }
    
    init(vector: PersistentVector<T>, count: Int) {
        // XXX count arg exists because the 1.2 compiler segfaults on vector.count
        self.init(count: count, shift: vector.shift, root: vector.root.transientVersion(transientID: ++transientVectorCounter), tail: vector.tail)
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
    
    private func transientChunk(index: Int, inout chunk: [T]) {
        chunk = index < tailOffset() ? root.getChunk(index: index, shift: self.shift) : tail
    }
    
    public mutating func conj(element: T) -> TransientVector {
        verifyTransient()
        
        if count - tailOffset() < 32 {
            tail.append(element)
        } else {
            let tailNode = LeafNode<T>(transientID: root.editID, children: tail)
            
            tail = []
            tail.reserveCapacity(32)
            tail.append(element)
            
            if count >> 5 > 1 << shift {
                root = TreeNode<T>(transientID: root.editID, children: [root, tailNode.newPath(transientID: root.editID, shift: shift)])
                shift += 5
            } else {
                root = root.transientPushTail(transientID: root.editID, count: count, shift: shift, tailNode: tailNode)
            }
        }
        
        count++
        return self
    }
    
    public mutating func persistent() -> PersistentVector<T> {
        verifyTransient()
        
        root.editID = 0
        
        var newTail = [T]()
        newTail.reserveCapacity(tail.count)
        newTail.extend(tail)
        
        return PersistentVector(count: count, shift: shift, root: root, tail: newTail)
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
            
            transientChunk(count - 2, chunk: &tail)
            
            if let r = root.transientPopTail(transientID: root.editID, count: count, shift: shift) {
                if let r2 = r.onlyChildNode() where shift > 5 {
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
        
        count--
        return self
    }
    
    public mutating func assoc(index: Int, _ element: T) -> TransientVector {
        verifyTransient()
        
        if index == count {
            return self.conj(element)
        }
        
        verifyBounds(index)
        
        if tailOffset() <= index {
            tail[index &  0x01f] = element
        } else {
            root = root.transientAssoc(transientID: root.editID, index: index, shift: shift, element: element)
        }
        
        return self
    }
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
