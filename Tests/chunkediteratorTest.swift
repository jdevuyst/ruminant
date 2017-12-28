//
//  chunkediteratorTest.swift
//  ruminantTests
//
//  Created by Stefan Boether on 28.12.17.


import XCTest

class ChunkedIteratorTest: XCTestCase {

    func testChunking() {
        
        // sequence of 32 elements chunked to size 5 (5,5,5,5,5,5,2)
        let fibonacciChunked =
            [
                [0, 1, 1, 2, 3],
                [5, 8, 13, 21, 34],
                [55, 89, 144, 233, 377],
                [610, 987, 1597, 2584, 4181],
                [6765, 10946, 17711, 28657, 46368],
                [75025, 121393, 196418, 317811, 514229],
                [832040, 1346269]
            ]
        
        let flatten = fibonacciChunked.flatMap { $0 }
        
        let getChunk =
            { (chunk: fibonacciChunked[$0 / 5], offset: $0 % 5) }
        
        let sequence = AnySequence { ChunkedIterator(f: getChunk, start: 0, end: 32) }.map { $0}
        XCTAssertEqual(flatten, sequence, "ChunkedIterator")
    }
}
