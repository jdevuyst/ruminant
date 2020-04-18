# Ruminant

A Swift implementation of [Clojure](http://clojure.org)'s [persistent data structures](http://en.wikipedia.org/wiki/Persistent_data_structure). Currently persistent and transient vectors are implemented. Persistent hash maps are next on my list.

## Persistent Vectors

All core operations on vectors have been implemented:

```swift
let v: PersistentVector = ["a", "b", "c"]
let v2 = v.conj("d").assoc(2, "C")
assert(v == ["a", "b", "c"])
assert(v2 == ["a", "b", "C", "d"])
assert(v.pop() == v2[0..<2])
assert(map(v, {$0.uppercaseString}) == ["A", "B", "C"])
```
## Integration

You should integrate it into your project with the Swift-Package Manager

```swift
dependencies: [
.package(url: "https://github.com/jdevuyst/ruminant", from: "1.0.6")
],
```

## Sample Usage

Here is a sample walkthrough with Swift Package Manager 4.0 to use this library

At first create a complete new directory from CLI named 'Sample' and change into it.

```bash
mkdir sample
cd sample
````

After this create a new exectuable swift template inside this directory

```bash
swift package init --type executable
```
Now you have the skeleton working directory. I use the swiftenv tool to manage my current installed swift versions. At the moment of writing this I have installed Swift 3.1.1 and 4.0.3. For this libary I used the newest version of Swift at the moment which is 4.0.3!

After this change the Swift-Packager Manifest a little bit (Package.swift)

```swift
// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sample",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/jdevuyst/ruminant", from: "1.0.6")
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

Now we can restore the dependencies with a small command

```bash
swift package update
```

So now we can check if we can use the PersistentVector type in our sample program by extending the Main.swift source

```swift
import ruminant

print("Hello, Persistent Vector!")

let sample = PersistentVector([1,2,3,4]).conj(45).conj(42)
print(sample)
```

After build and run the program from the commandline we should see the following output

```bash
swift build
swift run

Hello, Persistent Vector!
[1, 2, 3, 4, 45, 42]
```

So that's all. Enjoy the world of persistent datastructures.

## License

Copyright © 2015 Jonas De Vuyst

Distributed under the Eclipse Public License either version 1.0 or (at your option) any later version.
