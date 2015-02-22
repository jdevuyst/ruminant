# Ruminant

A Swift implementation of [Clojure](http://clojure.org)'s [persistent data structures](http://en.wikipedia.org/wiki/Persistent_data_structure). Currently persistent vectors are implemented. Persistent hash maps are next on my list.

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

Transient vectors have not yet been implemented, but I'm working on it.

## License

Copyright © 2015 Jonas De Vuyst

Distributed under the Eclipse Public License either version 1.0 or (at
your option) any later version.
