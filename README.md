# JSONUtilities

[![CI](https://github.com/yonaskolb/JSONUtilities/actions/workflows/ci.yml/badge.svg)](https://github.com/yonaskolb/JSONUtilities/actions/workflows/ci.yml)
[![](https://img.shields.io/cocoapods/v/JSONUtilities.svg)](https://cocoapods.org/pods/JSONUtilities)
[![](https://img.shields.io/cocoapods/p/JSONUtilities.svg)](https://cocoapods.org/pods/JSONUtilities)
![Carthage Compatible](https://img.shields.io/badge/carthage-compatible-4BC51D.svg?style=flat)
![Swift Version](https://img.shields.io/badge/swift-5.9-brightgreen.svg)

Easily load JSON objects and decode them into structs or classes. The `json(atKeyPath:)` function infers the type from the constant or variable definition to decode meaning no casting is needed. Both string keys and keypaths (keys separated by dots `.`) are supported when decoding JSON.

- Check out the `Example.playground` inside the `JSONUtilities.xcodeproj` for a working example

## Installation

**CocoaPods:**

Add the line `pod 'JSONUtilities'` to your `Podfile`.

**Carthage:**

Add the line `github "lucianomarisi/JSONUtilities"` to your `Cartfile`.

**Manual:**

Add the files inside the `Sources` folder into your Xcode project.

**Swift Package Manager:**

Add the line `.package(url: "https://github.com/yonaskolb/JSONUtilities.git", from: "4.2.0")` to the dependencies in your `Package.swift`.

## Types supported

### JSON raw types:

- `Int`
- `Double`
- `Float`
- `String`
- `Bool`
- `[String: AnyObject]`
- `RawRepresentable` enums

### Array of JSON raw types:

- `[Int]`
- `[Double]`
- `[Float]`
- `[String]`
- `[Bool]`
- `[[String: AnyObject]]`
- `[RawRepresentable]`

### Custom JSON objects and custom JSON object arrays

e.g. if `MyClass` and `MyStruct` conform to `JSONObjectConvertible` protocol

- `MyClass`
- [`MyClass`]
- `MyStruct`
- [`MyStruct`]

### Dictionaries with a `JSONKey`

- `[JSONKey: JSONRawType]`
- `[JSONKey: JSONObjectConvertible]`
- `[JSONKey: JSONPrimitiveConvertible]`
- `[JSONKey: RawRepresentable]`

String already conforms to JSONKey. It's also easy to make enum keys by just making them conform to JSONKey which requires a `var key: String { get }`, and an `init?(rawValue: String)` which RawRepresentable already conforms to e.g:

```
enum MyEnum: String, JSONKey {
	case one
	case two
	
	var key: String {
		return rawValue
	}
}
```

## InvalidItemBehaviour

When decoding arrays or dictionaries an `invalidItemBehaviour` parameter can be passed which controls what happens when an error occurs while decoding child items

- `.remove` this will simply remove the item from the array or dictionary. This is the default
- `.fail` if any of the children encounter an error the whole array or dictionary decoding will fail. For optional properties this means the array or dictionary will return nil, and for non optional properties it will throw an error
- `.value(T)` Provide an alternative value
- `.custom((DecodingError) -> InvalidItemBehaviour)` Lets you specify the behaviour based on the specific DecodingError

## KeyPath
Each json(atKeyPath:) function takes a KeyPath. This is an enum with 2 cases:

- `key(String)` - this does a single key lookup
- `keyPath([String])` - this does a nested key lookup

KeyPath can be initialized with a string literal. When doing so, if there are any `.` it will be treated as a keypath instead of a simple key.

When providing keyPaths, an int allows lookup up a value in an array by index. eg: `"myArray.1"` string literal will look for the key `myArray ` and then the 2nd item if that value is an array (indices are 0 based)

## Examples of JSON loading

### From file

```swift
let filename = "myjsonfile"
let dictionary: [String: AnyObject] = try JSONDictionary.from(filename: filename)
```

### From data

```swift
let data: Data = ...
let dictionary: [String: AnyObject] = try JSONDictionary.from(jsonData: data)
```

## Examples of JSON decoding

Consider a JSON object that represents a person:

```json
{
  "name" : "John Doe",
  "age" : 24,
  "weight" : 72.4
}
```

### Decode JSON inline

```swift
let jsonDictionary = try JSONDictionary.from(filename: "person.json")
let name: String = try jsonDictionary.json(atKeyPath: "name")
let age: Int = try jsonDictionary.json(atKeyPath: "age")
let weight: Int = try jsonDictionary.json(atKeyPath: "weight")
let profession: String? = jsonDictionary.json(atKeyPath: "profession") // Optional decoding
```

### Decode structs or classes

```swift
struct Person { //OR class Person {

  let name: String
  let age: Int
  let weight: Double
  let profession: String?

  init(jsonDictionary: JSONDictionary) throws {
    name = try jsonDictionary.json(atKeyPath: "name")
    age = try jsonDictionary.json(atKeyPath: "age")
    weight = try jsonDictionary.json(atKeyPath: "weight")
    profession = jsonDictionary.json(atKeyPath: "profession")
  }

}
```

### Decode nested structs or classes by conforming to the JSONObjectConvertible protocol

Consider a company JSON object:

```json
{
    "name" : "Working name LTD.",
    "employees": [
        {
            "name": "John Doe",
            "age": 24,
            "weight": 72.4
        },
        {
            "name": "Jane Doe",
            "age": 22,
            "weight": 70.1
        }
    ]
}
```

The `Company` struct can decode an array of `Person` structs/classes by making `Person` conform to the `JSONObjectConvertible` protocol

```swift
struct Company {
  let name: String
  let employees: [Person]

  init(jsonDictionary: JSONDictionary) throws {
    name = try jsonDictionary.json(atKeyPath: "name")
    employees = try jsonDictionary.json(atKeyPath: "employees")
  }
}
```

### Support custom primitive types by conforming to `JSONPrimitiveConvertible`

Any type can extend the `JSONPrimitiveConvertible` protocol in order to allow decoding. For example extending `URL`: **Note that this extension come out of the box**
:

```swift
extension URL: JSONPrimitiveConvertible {

  public typealias JSONType = String

  public static func from(jsonValue: String) -> Self? {
    return self.init(string: jsonValue)
  }

}

let urlDictionary = ["url": "www.google.com"]
let url: URL = try! urlDictionary.json(atKeyPath: "url") // www.google.com
```


It's also possible to have an array of `JSONPrimitiveConvertible` values, for example:

```swift
let urlsDictionary = ["urls": ["www.google.com", "www.yahoo.com"]]
let urls: [URL] = try! urlsDictionary.json(atKeyPath: "urls") // [www.google.com, www.yahoo.com]
```

## Unused key tracking

`KeyAccessTracking` can report keys that were present in your JSON but never read while decoding it, which is useful for warning about typos or unsupported keys. It's opt-in and does nothing unless you decode inside `KeyAccessTracking.record`.

```swift
let json: JSONDictionary = ["name": "App", "child": ["name": "Child", "nmae": "typo"], "extra": 1]

let (parent, unusedKeys) = try KeyAccessTracking.record(root: json) {
    try Parent(jsonDictionary: json)
}
unusedKeys.map { $0.description } // ["child.nmae", "extra"]
```

Every `JSONObjectConvertible` decoded with `json(atKeyPath:)` gets its own scope, and unused keys are reported with their path, including array indexes like `children[1].key`. Keys are marked as read when they are accessed with `json(atKeyPath:)`, whether or not they decode successfully.

- `KeyAccessTracking.markRead("key")` marks keys you read some other way, like `jsonDictionary["key"]`.
- `KeyAccessTracking.markAllRead()` marks every key of the current object as read, for objects whose keys are data.
- `KeyAccessTracking.scope(dictionary, at: ["sources", .index(1)]) { ... }` gives an object you decode yourself its own scope, at a path relative to the current one.
- Each `UnusedKey` has a `path` of `JSONPathComponent`s (`.key` or `.index`) and the unused `key`. Its `description` is the full path, like `sources[1].buildphase`.
- The current scope is a task local, so separate recordings never mix and child tasks continue their parent's recording. Threads that don't inherit task locals, like `DispatchQueue.concurrentPerform`, can continue it by capturing `KeyAccessTracking.currentContext` and running their decoding inside `KeyAccessTracking.withContext(context) { ... }`.

