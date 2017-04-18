//
//  SourceEditorCommand.swift
//  TestSourceEditor
//
//  Created by Tim on 4/17/17.
//  Copyright © 2017 Tim Shadel. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {

    static let describePattern = try! NSRegularExpression(pattern: "^//\\s*describe\\s+(.*)", options: [])
    static let whenPattern = try! NSRegularExpression(pattern: "^\\s*//\\s*when\\s+it\\s+(.*)", options: [])
    static let itPattern = try! NSRegularExpression(pattern: "^(\\s*)//\\s*it\\s+(.*)", options: [])
    static let blankPattern = try! NSRegularExpression(pattern: "^\\s*$", options: [])

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        var it: String?
        var when: String?
        var expect: String?
        var expectPrefix: String?
        var expectIndent: String?

        var originalLines = [Any]()
        originalLines.append(contentsOf: invocation.buffer.lines)
        var newIndex = -1

        for line in originalLines {
            newIndex += 1
            guard let line = line as? String else { continue }
            let fullLineRange = NSMakeRange(0, line.characters.count)

            // Correct this line...
            if let expected = expect, let prefix = expectPrefix, let indent = expectIndent, line != expected {
                // ...by replacing the current line
                if line.matches(prefix) {
                    invocation.buffer.lines[newIndex] = expected
                    let selection = XCSourceTextRange(start: XCSourceTextPosition(line: newIndex, column: indent.characters.count), end: XCSourceTextPosition(line: newIndex, column: expected.characters.count - 1))
                    invocation.buffer.selections.add(selection)
                // ...by inserting new code
                } else {
                    invocation.buffer.lines.insert(expected, at: newIndex)
                    invocation.buffer.lines.insert("\(indent)}\n", at: newIndex + 1)
                    let selection = XCSourceTextRange(start: XCSourceTextPosition(line: newIndex, column: indent.characters.count), end: XCSourceTextPosition(line: newIndex + 1, column: indent.characters.count + 1))
                    invocation.buffer.selections.add(selection)
                    newIndex += 2
                }

                expect = nil
                expectPrefix = nil
                expectIndent = nil
                continue
            // No correction required
            } else {
                expect = nil
                expectPrefix = nil
                expectIndent = nil
            }

            // Defines the subject of our specs
            if let result = SourceEditorCommand.describePattern.firstMatch(in: line, options: [], range: fullLineRange), let range = line.range(for: result.rangeAt(1)) {
                it = line[range].typeCased
                continue
            }
            guard let it = it else { continue }

            // Defines the context of the specs
            if let result = SourceEditorCommand.whenPattern.firstMatch(in: line, options: [], range: fullLineRange), let range = line.range(for: result.rangeAt(1)) {
                when = "when \(it) \(line[range])".typeCased
                expect = "class \(when!): XCTestCase {\n"
                expectPrefix = "^class "
                expectIndent = ""
                continue
            }

            // Defines the test case within a context
            if let result = SourceEditorCommand.itPattern.firstMatch(in: line, options: [], range: fullLineRange), let spaceRange = line.range(for: result.rangeAt(1)), let nameRange = line.range(for: result.rangeAt(2)) {
                let spaces = line[spaceRange]
                let name = "test \(it) \(line[nameRange])".camelCased
                expect = "\(spaces)func \(name)() {\n"
                expectPrefix = "\\s+func "
                expectIndent = spaces
                continue
            }
        }

        completionHandler(nil)
    }
    
}


extension String {

    /// - Returns: a Swift range on this string for the given NSRange, taking into account multi-byte characters like emoji.
    /// Thank you http://stackoverflow.com/a/30404532/1330722
    func range(for range: NSRange) -> ClosedRange<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: range.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(utf16.startIndex, offsetBy: range.location + range.length - 1, limitedBy: utf16.endIndex),
            let from = from16.samePosition(in: self),
            let to = to16.samePosition(in: self)
            else { return nil }
        return from...to
    }

    /// - Returns: a string where all whitespace has been removed, all words have had the first letter capitalized
    var typeCased: String {
        get {
            return self.components(separatedBy: CharacterSet.whitespaces).map { w in w.firstCapitalized }.joined()
        }
    }

    /// - Returns: a string where all whitespace has been removed, all words have had the first letter capitalized with
    ///            the first letter of the first word lowercased.
    var camelCased: String {
        get {
            return self.components(separatedBy: CharacterSet.whitespaces).map { w in w.firstCapitalized }.joined().firstLowercased
        }
    }

    /// - Returns: a copy of this string with the first letter capitalized and all others left in their current case
    private var firstCapitalized: String {
        get {
            var copy = self
            let first = "\(copy.remove(at: copy.startIndex))".capitalized
            return "\(first)\(copy)"
        }
    }

    /// - Returns: a copy of this string with the first letter lowercased and all others left in their current case
    private var firstLowercased: String {
        get {
            var copy = self
            let first = "\(copy.remove(at: copy.startIndex))".lowercased()
            return "\(first)\(copy)"
        }
    }

    func matches(_ pattern: String) -> Bool {
        let expression = try! NSRegularExpression(pattern: pattern, options: [])
        return expression.matches(in: self, options: [], range: NSMakeRange(0, self.characters.count)).count > 0
    }

}

