# Ruminant

A Swift implementation of [Clojure](http://clojure.org)'s [persistent](http://en.wikipedia.org/wiki/Persistent_data_structure) vectors.

## Persistent Vectors

Core operations such as `conj`, `assoc`, `get` (using subscripts), `subvec` (using subscripts), and `concat` have been implemented.

```swift
let v: PersistentVector = ["a", "b", "c"]
let v2 = v.conj("d").assoc(index: 2, "C")
XCTAssertEqual(v, ["a", "b", "c"])
XCTAssertEqual(v2, ["a", "b", "C", "d"])
XCTAssert(v.pop() == v2[0..<2])
XCTAssertEqual(v.map {$0.uppercased()}, ["A", "B", "C"])
XCTAssertEqual(v[1], "b")
XCTAssertEqual(Array(v[1...2]), ["b", "c"])
```

Transient vectors are included:

```swift
let v: PersistentVector = ["a", "b", "c"]
var tmp = v.transient()
tmp = tmp.pop()
tmp = tmp.conj("3")
tmp = tmp.conj("4")
XCTAssert(tmp.persistent() == ["a", "b", "3", "4"])
```

## Integration

You can use the Swift-Package manager to integrate Ruminant.

Add the following dependency in `Package.swift`:

```swift
dependencies: [
.package(url: "https://github.com/jdevuyst/ruminant", from: "1.0.7")
],
```

## Sample Usage

Here is a sample walkthrough with Swift Package Manager to use this library.

First, create a complete new directory from CLI named "Sample" and `cd` into it.

```bash
mkdir sample
cd sample
````

Next, create a new exectuable swift template inside this directory.

```bash
swift package init --type executable
```

Now it's time to update `Package.swift`.

```swift
// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sample",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/jdevuyst/ruminant", from: "1.0.7")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "sample",
            dependencies: ["ruminant"])
    ]
)
```

Let's install the new dependency.

```bash
swift package update
```

We'll also updatee `Main.swift` to test that Ruminant can be loaded.

```swift
import ruminant

print("Hello, Persistent Vector!")

let sample = PersistentVector([1,2,3,4]).conj(45).conj(42)
print(sample)
```

Finally, we can build and run the program from the command line.

```bash
swift build
swift run

Hello, Persistent Vector!
[1, 2, 3, 4, 45, 42]
```

That's it. Enjoy the world of persistent datastructures!

## License

Copyright © 2015 Jonas De Vuyst

Distributed under the Eclipse Public License either version 1.0 or (at your option) any later version.
