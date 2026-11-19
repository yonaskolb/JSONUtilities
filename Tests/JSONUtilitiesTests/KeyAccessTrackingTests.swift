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

    func testConcurrentScopes() throws {
        var items: JSONDictionary = [:]
        for index in 0..<50 {
            items["item\(index)"] = ["name": "item\(index)", "unknown\(index)": true]
        }
        let dictionary: JSONDictionary = ["items": items]

        let (names, unusedKeys) = try KeyAccessTracking.record(root: dictionary) { () -> [String] in
            let itemsDictionary: JSONDictionary = try dictionary.json(atKeyPath: "items")
            let basePath = KeyAccessTracking.currentPath ?? []
            let keys = Array(itemsDictionary.keys)
            let lock = NSLock()
            var names: [String] = []
            DispatchQueue.concurrentPerform(iterations: keys.count) { index in
                let key = keys[index]
                let itemDictionary = itemsDictionary[key] as! JSONDictionary
                let child = try? KeyAccessTracking.scope(itemDictionary, path: basePath + ["items", key]) {
                    try TrackedChild(jsonDictionary: itemDictionary)
                }
                lock.lock()
                names.append(child?.name ?? "")
                lock.unlock()
            }
            return names
        }

        XCTAssertEqual(names.count, 50)
        XCTAssertEqual(unusedKeys.count, 50)
        XCTAssertEqual(Set(unusedKeys.map { $0.description }), Set((0..<50).map { "items.item\($0).unknown\($0)" }))
    }
}
