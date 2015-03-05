//
//  util.swift
//  RUMINANT – Swift persistent data structures à la Clojure
//
//  Created by Jonas De Vuyst on 19/02/15.
//  Copyright (c) 2015 Jonas De Vuyst. All rights reserved.
//

func arrayPop<T>(let arr: [T]) -> [T] {
    var arr2 = [T]()
    arr2.reserveCapacity(arr.count - 1)
    arr2.extend(arr[0..<arr.count - 1])
    return arr2
}

func arrayConj<T>(let arr: [T], val: T) -> [T] {
    var arr2 = [T]()
    arr2.reserveCapacity(arr.count + 1)
    arr2.extend(arr)
    arr2.append(val)
    return arr2
}

func arrayAssoc<T>(var arr: [T], idx: Int, val: T) -> [T] {
    arr[idx] = val
    return arr
}

func seqDescription<T: SequenceType>(xs: T, ldelim: String, rdelim: String) -> String {
    let xs = map(xs) {"\($0)"}
    let s = join(", ", xs)
    return "\(ldelim)\(s)\(rdelim)"
}

func seqDebugDescription<T: SequenceType>(xs: T, ldelim: String, rdelim: String) -> String {
    let xs: [String] = map(xs) {x in
        if let x = x as? DebugPrintable {
            return x.debugDescription
        } else {
            return "\(x)"
        }
    }
    let s = join(", ", xs)
    return "\(ldelim)\(s)\(rdelim)"
}