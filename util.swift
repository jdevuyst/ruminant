//
//  util.swift
//  RUMINANT – Swift persistent data structures à la Clojure
//
//  Created by Jonas De Vuyst on 19/02/15.
//  Copyright (c) 2015 Jonas De Vuyst. All rights reserved.
//

func arrayPop<T>(_ arr: [T]) -> [T] {
    var arr2 = [T]()
    arr2.reserveCapacity(arr.count - 1)
    arr2.append(contentsOf:arr[0..<arr.count - 1])
    return arr2
}

func arrayConj<T>(_ arr: [T], val: T) -> [T] {
    var arr2 = [T]()
    arr2.reserveCapacity(arr.count + 1)
    arr2.append(contentsOf: arr)
    arr2.append(val)
    return arr2
}

func arrayAssoc<T>(_ arr: inout [T], idx: Int, val: T) -> [T] {
    arr[idx] = val
    return arr
}

func seqDescription<T: Sequence>(xs: T, ldelim: String, rdelim: String) -> String {
    let xs = xs.map {"\($0)"}
    let s = xs.joined(separator: ", ")
    return "\(ldelim)\(s)\(rdelim)"
}

func seqDebugDescription<T: Sequence>(xs: T, ldelim: String, rdelim: String) -> String {
    let xs: [String] = xs.map {x in
        if let x = x as? CustomDebugStringConvertible {
            return x.debugDescription
        } else {
            return "\(x)"
        }
    }
    let s = xs.joined(separator: ", ")
    return "\(ldelim)\(s)\(rdelim)"
}

