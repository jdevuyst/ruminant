//
//  Created by Jonas De Vuyst on 18/02/15.
//  Copyright (c) 2015 Jonas De Vuyst. All rights reserved.
//
//  chunkediterator.swift

// n.b. ChunkedIterator copies can be advanced independently when backed by a persistent data structure

// https://www.uraimo.com/2015/11/12/experimenting-with-swift-2-sequencetype-generatortype/

public class ChunkedIterator<T>: IteratorProtocol {
    
    public typealias Element = T
    public typealias ChunkFunction = (Int) -> (chunk: [T], offset: Int)
    
    public let f: ChunkFunction
    private let end: Int
    
    private var i: Int
    private var j = 0
    private var chunk: [T]
    
    init(f: @escaping ChunkFunction, start: Int, end: Int) {
        assert(end >= start)
        self.f = f
        self.i = start
        self.end = end
        (chunk: self.chunk, offset: self.j) = end - start == 0 ? ([], 0) : f(start)
    }
    
    public func next() -> T? {
        guard i < end else {
            return nil
        }
        
        if j == chunk.count {
            (chunk: chunk, offset: j) = f(i)
        }
        
        i += 1
        defer {
            j += 1
        }
        return chunk[j]
    }
}
