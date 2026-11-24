//
//  KeyAccessTrackingTests.swift
//  JSONUtilities
//

import Foundation
import XCTest
@testable import JSONUtilities

private struct TrackedChild: JSONObjectConvertible {
    let name: String

    init(jsonDictionary: JSONDictionary) throws {
        name = try jsonDictionary.json(atKeyPath: "name")
    }
}

private struct TrackedParent: JSONObjectConvertible {
    let name: String
    let child: TrackedChild?
    let children: [TrackedChild]
    let childMap: [String: TrackedChild]
    let nestedArrays: [[TrackedChild]]
    let freeForm: JSONDictionary?
    let nestedValue: String?

    init(jsonDictionary: JSONDictionary) throws {
        name = try jsonDictionary.json(atKeyPath: "name")
        child = jsonDictionary.json(atKeyPath: "child")
        children = jsonDictionary.json(atKeyPath: "children") ?? []
        childMap = jsonDictionary.json(atKeyPath: "childMap") ?? [:]
        nestedArrays = jsonDictionary.json(atKeyPath: "nestedArrays") ?? []
        freeForm = jsonDictionary.json(atKeyPath: "freeForm")
        nestedValue = jsonDictionary.json(atKeyPath: "nested.value")
    }
}

private struct MarkingObject: JSONObjectConvertible {

    init(jsonDictionary: JSONDictionary) throws {
        KeyAccessTracking.markRead("consumedElsewhere")
        if jsonDictionary["isFreeForm"] as? Bool == true {
            KeyAccessTracking.markAllRead()
        }
    }
}

class KeyAccessTrackingTests: XCTestCase {

    func testNotRecordingByDefault() throws {
        XCTAssertFalse(KeyAccessTracking.isRecording)
        XCTAssertNil(KeyAccessTracking.currentPath)
        let parent = try TrackedParent(jsonDictionary: ["name": "parent", "unknown": 1])
        XCTAssertEqual(parent.name, "parent")
        XCTAssertFalse(KeyAccessTracking.isRecording)
    }

    func testAllKeysRead() throws {
        let dictionary: JSONDictionary = [
            "name": "parent",
            "child": ["name": "child"],
            "children": [["name": "a"]],
        ]
        let (parent, unusedKeys) = try KeyAccessTracking.record(root: dictionary) {
            try TrackedParent(jsonDictionary: dictionary)
        }
        XCTAssertEqual(parent.children.count, 1)
        XCTAssertEqual(unusedKeys, [])
        XCTAssertFalse(KeyAccessTracking.isRecording)
    }

    func testReportsUnusedKeysWithPaths() throws {
        let dictionary: JSONDictionary = [
            "name": "parent",
            "typo": 1,
            "child": ["name": "child", "extra": 1],
            "children": [["name": "a"], ["name": "b", "oops": true]],
            "childMap": ["x": ["name": "x", "bad": 1]],
            "nestedArrays": [[["name": "a"]], [["name": "b", "deep": 1]]],
            "freeForm": ["anything": 1, "goes": 2],
            "nested": ["value": "v", "other": 1],
        ]
        let (parent, unusedKeys) = try KeyAccessTracking.record(root: dictionary) {
            try TrackedParent(jsonDictionary: dictionary)
        }
        XCTAssertEqual(parent.nestedValue, "v")
        XCTAssertEqual(unusedKeys.map { $0.description }, [
            "child.extra",
            "childMap.x.bad",
            "children[1].oops",
            "nestedArrays[1][0].deep",
            "typo",
        ])
        XCTAssertEqual(unusedKeys.last, UnusedKey(path: [], key: "typo"))
    }

    func testWithoutRootOnlyNestedObjectsAreChecked() throws {
        let dictionary: JSONDictionary = ["parent": ["name": "parent", "typo": 1], "ignored": 1]
        let (_, unusedKeys) = try KeyAccessTracking.record {
            try dictionary.json(atKeyPath: "parent") as TrackedParent
        }
        XCTAssertEqual(unusedKeys.map { $0.description }, ["parent.typo"])
    }

    func testUnusedKeysSortIndexesNumerically() throws {
        let children: [JSONDictionary] = (0..<12).map { ["name": "\($0)", "extra": 1] }
        let dictionary: JSONDictionary = ["name": "parent", "children": children]
        let (_, unusedKeys) = try KeyAccessTracking.record(root: dictionary) {
            try TrackedParent(jsonDictionary: dictionary)
        }
        XCTAssertEqual(unusedKeys.map { $0.description }, (0..<12).map { "children[\($0)].extra" })
        XCTAssertEqual(unusedKeys[1].path, [.key("children"), .index(1)])
    }

    func testScopeWithPathComponents() throws {
        let source: JSONDictionary = ["name": "a", "typo": 1]
        let (_, unusedKeys) = try KeyAccessTracking.record {
            try KeyAccessTracking.scope(source, at: "targets", "App", "sources", 1) {
                XCTAssertEqual(KeyAccessTracking.currentPath, [.key("targets"), .key("App"), .key("sources"), .index(1)])
                return try TrackedChild(jsonDictionary: source)
            }
        }
        XCTAssertEqual(unusedKeys, [UnusedKey(path: ["targets", "App", "sources", 1], key: "typo")])
        XCTAssertEqual(unusedKeys.map { $0.description }, ["targets.App.sources[1].typo"])
    }

    func testFailedDecodesAreNotReported() throws {
        let dictionary: JSONDictionary = [
            "name": "parent",
            "children": [["name": "a"], ["missingName": true]],
        ]
        let (parent, unusedKeys) = try KeyAccessTracking.record(root: dictionary) {
            try TrackedParent(jsonDictionary: dictionary)
        }
        XCTAssertEqual(parent.children.count, 1)
        XCTAssertEqual(unusedKeys, [])
    }

    func testMarkReadAndMarkAllRead() throws {
        let dictionary: JSONDictionary = [
            "marked": ["consumedElsewhere": 1, "unknown": 1],
            "freeForm": ["isFreeForm": true, "anything": 1],
        ]
        let (_, unusedKeys) = try KeyAccessTracking.record {
            _ = try dictionary.json(atKeyPath: "marked") as MarkingObject
            _ = try dictionary.json(atKeyPath: "freeForm") as MarkingObject
        }
        XCTAssertEqual(unusedKeys.map { $0.description }, ["marked.unknown"])
    }

    func testScopeOutsideRecordingIsNoOp() throws {
        let child = try KeyAccessTracking.scope(["name": "a", "unknown": 1], at: "child") {
            try TrackedChild(jsonDictionary: ["name": "a", "unknown": 1])
        }
        XCTAssertEqual(child.name, "a")
        KeyAccessTracking.markRead("anything")
        KeyAccessTracking.markAllRead()
        XCTAssertNil(KeyAccessTracking.currentPath)
    }

    func testConcurrentScopesWithContext() throws {
        var items: JSONDictionary = [:]
        for index in 0..<50 {
            items["item\(index)"] = ["name": "item\(index)", "unknown\(index)": true]
        }
        let dictionary: JSONDictionary = ["items": items]

        let (names, unusedKeys) = try KeyAccessTracking.record(root: dictionary) { () -> [String] in
            let itemsDictionary: JSONDictionary = try dictionary.json(atKeyPath: "items")
            return try KeyAccessTracking.scope(itemsDictionary, at: "items", allKeysRead: true) {
                let context = KeyAccessTracking.currentContext
                XCTAssertNotNil(context)
                let keys = Array(itemsDictionary.keys)
                let lock = NSLock()
                var names: [String] = []
                DispatchQueue.concurrentPerform(iterations: keys.count) { index in
                    let key = keys[index]
                    let child = try? KeyAccessTracking.withContext(context) {
                        try itemsDictionary.json(atKeyPath: .key(key)) as TrackedChild
                    }
                    lock.lock()
                    names.append(child?.name ?? "")
                    lock.unlock()
                }
                return names
            }
        }

        XCTAssertEqual(names.count, 50)
        XCTAssertEqual(unusedKeys.count, 50)
        XCTAssertEqual(Set(unusedKeys.map { $0.description }), Set((0..<50).map { "items.item\($0).unknown\($0)" }))
    }

    func testSeparateRecordingsDontInterfere() {
        let lock = NSLock()
        var results: [Int: [String]] = [:]
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            let dictionary: JSONDictionary = ["name": "parent", "unknown\(index)": true, "child": ["name": "child", "extra\(index)": 1]]
            let (_, unusedKeys) = try! KeyAccessTracking.record(root: dictionary) {
                try TrackedParent(jsonDictionary: dictionary)
            }
            lock.lock()
            results[index] = unusedKeys.map { $0.description }
            lock.unlock()
        }
        for index in 0..<20 {
            XCTAssertEqual(results[index], ["child.extra\(index)", "unknown\(index)"])
        }
    }

    func testNestedRecordingsAreSeparate() throws {
        let outer: JSONDictionary = ["name": "outer", "outerUnknown": 1]
        let inner: JSONDictionary = ["name": "inner", "innerUnknown": 1]
        let (innerKeys, outerKeys) = try KeyAccessTracking.record(root: outer) { () -> [UnusedKey] in
            _ = try TrackedParent(jsonDictionary: outer)
            return try KeyAccessTracking.record(root: inner) { try TrackedParent(jsonDictionary: inner) }.1
        }
        XCTAssertEqual(innerKeys.map { $0.description }, ["innerUnknown"])
        XCTAssertEqual(outerKeys.map { $0.description }, ["outerUnknown"])
    }
}
