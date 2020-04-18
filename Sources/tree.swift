//
//  tree.swift
//  RUMINANT – Swift persistent data structures à la Clojure
//
//  Created by Jonas De Vuyst on 19/02/15.
//  Copyright (c) 2015 Jonas De Vuyst. All rights reserved.
//

// This function is used a lot and that is not a good thing.
//
// At the time when this project was started, @indirect enums were not yet
// available in Swift. This was quite unfortunate, because sum types are
// the usual way to implement trees. Using @indirect enums, a lot of illegal
// states that are presently guarded by an `unreachable()` call, could be
// made unrepresentable.
private func unreachable() -> Never {
    preconditionFailure("This code should be unreachable")
}

//
//  MARK: - Node Types
//

class Node<T: Hashable> {
    var editID: Int
    
    init(transientID: Int) {
        self.editID = transientID
    }
    
    func transientVersion(_ transientID: Int) -> Node<T> { unreachable() }
    
    func getChunk(_ index: Int, shift: Int) -> [T] { unreachable() }
    
    func transientChunk(_ transientID: Int, index: Int, shift: Int, chunk: inout [T]) { unreachable() }
    
    func newPath(_ transientID: Int, shift: Int) -> Node {
        return shift == 0
            ? self
            : TreeNode(transientID: transientID, children: [self])
                .newPath(transientID, shift: shift - 5)
    }
    
    func pushTail(_ count: Int, shift: Int, tailNode: Node<T>) -> Node<T> { unreachable() }
    
    func transientPushTail(_ transientID: Int, count: Int, shift: Int, tailNode: Node<T>) -> Node<T> { unreachable() }
    
    func popTail(_ count: Int, shift: Int) -> Node<T>? { unreachable() }
    
    func transientPopTail(_ transientID: Int, count: Int, shift: Int) -> Node<T>? { unreachable() }
    
    func assoc(_ index: Int, shift: Int, element: T) -> Node { unreachable() }
    
    func transientAssoc(_ transientID: Int, index: Int, shift: Int, element: T) -> Node { unreachable() }
    
    func onlyChildNode() -> Node? { unreachable() }
}

internal class TreeNode<T: Hashable> : Node<T> {
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
    
    override func transientVersion(_ transientID: Int) -> TreeNode {
        if self.editID == transientID {
            return self
        }
        
        var newChildren = [Node<T>]()
        newChildren.reserveCapacity(32)
        newChildren.append(contentsOf: children)
        return TreeNode<T>(transientID: transientID, children: newChildren)
    }
    
    override func getChunk(_ index: Int, shift: Int) -> [T] {
        assert(shift > 0)
        return children[(index >> shift) & 0x01f].getChunk(index, shift: shift - 5)
    }
    
    override func transientChunk(_ transientID: Int, index: Int, shift: Int, chunk: inout [T]) {
        assert(shift > 0)
        children[(index >> shift) & 0x01f].transientChunk(transientID, index: index, shift: shift - 5, chunk: &chunk)
    }
    
    override func pushTail(_ count: Int, shift: Int, tailNode: Node<T>) -> Node<T> {
        assert(shift > 0)
        let subidx = ((count - 1) >> shift) & 0x01f
        
        let newChildren: [Node<T>]
        
        if(shift == 5) {
            assert(subidx == children.count)
            newChildren = arrayConj(children, val: tailNode)
        } else if subidx == children.count {
            newChildren = arrayConj(children, val: tailNode.newPath(0, shift: shift - 5))
        } else {
            newChildren = arrayAssoc(&children, idx: subidx, val: children[subidx].pushTail(count, shift: shift - 5, tailNode: tailNode))
        }
        
        return TreeNode(transientID: self.editID, children: newChildren)
    }
    
    override func transientPushTail(_ transientID: Int, count: Int, shift: Int, tailNode: Node<T>) -> Node<T> {
        assert(shift > 0)
        
        let transientSelf = self.transientVersion(transientID)
        let subidx = ((count - 1) >> shift) & 0x01f
        
        if(shift == 5) {
            assert(subidx == children.count)
            children.append(tailNode)
        } else if subidx == children.count {
            children.append(tailNode.newPath(transientID, shift: shift - 5))
        } else {
            children[subidx] = children[subidx].pushTail(count, shift: shift - 5, tailNode: tailNode)
        }
        
        return transientSelf
    }
    
    override func popTail(_ count: Int, shift: Int) -> Node<T>? {
        let subidx = ((count - 2) >> shift) & 0x01f
        
        if shift > 5 {
            if let newChild = children[subidx].popTail(count, shift: shift - 5) {
                return TreeNode(transientID: self.editID, children: arrayAssoc(&children, idx: subidx, val: newChild))
            }
        }
        
        assert(subidx == children.count - 1)
        return subidx == 0 ? nil : TreeNode(transientID: self.editID, children: arrayPop(children))
    }
    
    override func transientPopTail(_ transientID: Int, count: Int, shift: Int) -> Node<T>? {
        let subidx = ((count - 2) >> shift) & 0x01f
        
        if shift > 5 {
            if let newChild = children[subidx].transientPopTail(transientID, count: count, shift: shift - 5) {
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
    
    override func assoc(_ index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift > 0)
        let subidx = (index >> shift) & 0x01f
        let newChildren = arrayAssoc(&children, idx: subidx, val: children[subidx].assoc(index, shift: shift - 5, element: element))
        return TreeNode(transientID: self.editID, children: newChildren)
    }
    
    override func transientAssoc(_ transientID: Int, index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift > 0)
        let subidx = (index >> shift) & 0x01f
        let transientSelf = transientVersion(transientID)
        transientSelf.children[subidx] = children[subidx].transientAssoc(transientID, index: index, shift: shift - 5, element: element)
        return transientSelf
    }
    
    override func onlyChildNode() -> Node<T>? {
        return children.count == 1 ? children[0] : nil
    }
}

internal class LeafNode<T: Hashable> : Node<T> {
    private var children: [T]
    
    init(transientID: Int, children: [T]) {
        assert(children.count == 32)
        assert(children.capacity == 32)
        self.children = children
        super.init(transientID: transientID)
    }
    
    override func transientVersion(_ transientID: Int) -> LeafNode {
        assert(transientID != 0)
        return self.editID == transientID ? self : LeafNode<T>(transientID: transientID, children: children)
    }
    
    override func getChunk(_ index: Int, shift: Int) -> [T] {
        assert(shift == 0)
        return children
    }
    
    override func transientChunk(_ transientID: Int, index: Int, shift: Int,  chunk: inout [T]) {
        assert(shift == 0)
        let transientSelf = transientVersion(transientID)
        chunk = transientSelf.children
    }
    
    override func assoc(_ index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift == 0)
        let subidx = index & 0x01f
        return LeafNode(transientID: self.editID, children: arrayAssoc(&children, idx: subidx, val: element))
    }
    
    override func transientAssoc(_ transientID: Int, index: Int, shift: Int, element: T) -> Node<T> {
        assert(shift == 0)
        let subidx = index & 0x01f
        let transientSelf = transientVersion(transientID)
        transientSelf.children[subidx] = element
        return transientSelf
    }
}

