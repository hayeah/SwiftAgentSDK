import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftParser
import XCTest
@testable import SwiftUITapMacros

final class MethodParsingTests: XCTestCase {

    // MARK: - Helpers

    private func parseMethods(_ source: String) -> [MethodInfo] {
        let sourceFile = Parser.parse(source: source)
        guard let classDecl = sourceFile.statements.first?.item.as(ClassDeclSyntax.self) else {
            XCTFail("Expected a class declaration")
            return []
        }
        return extractMethods(from: classDecl)
    }

    private func generateCall(_ source: String) -> String {
        let methods = parseMethods(source)
        return generateAgentCall(methods: methods)
    }

    private func expect(_ build: (CodeBuilder) -> Void) -> String {
        let b = CodeBuilder()
        build(b)
        return b.build()
    }

    // MARK: - extractMethods: param parsing

    func testSimpleLabel() {
        let methods = parseMethods("""
        final class S {
            func addTodo(title: String) {}
        }
        """)

        XCTAssertEqual(methods.count, 1)
        let m = methods[0]
        XCTAssertEqual(m.name, "addTodo")
        XCTAssertEqual(m.params.count, 1)
        XCTAssertEqual(m.params[0].label, "title")
        XCTAssertEqual(m.params[0].internalName, "title")
        XCTAssertEqual(m.params[0].jsonKey, "title")
        XCTAssertEqual(m.params[0].type, "String")
    }

    func testKeywordLabel() {
        let methods = parseMethods("""
        final class S {
            func book(for bookID: String) -> String? { nil }
        }
        """)

        XCTAssertEqual(methods.count, 1)
        let m = methods[0]
        XCTAssertEqual(m.name, "book")
        XCTAssertEqual(m.params[0].label, "for")
        XCTAssertEqual(m.params[0].internalName, "bookID")
        XCTAssertEqual(m.params[0].jsonKey, "for")
    }

    func testMixedLabels() {
        let methods = parseMethods("""
        final class S {
            func move(from source: Int, to destination: Int) {}
        }
        """)

        XCTAssertEqual(methods.count, 1)
        let m = methods[0]
        XCTAssertEqual(m.params.count, 2)

        XCTAssertEqual(m.params[0].label, "from")
        XCTAssertEqual(m.params[0].internalName, "source")
        XCTAssertEqual(m.params[0].jsonKey, "from")

        XCTAssertEqual(m.params[1].label, "to")
        XCTAssertEqual(m.params[1].internalName, "destination")
        XCTAssertEqual(m.params[1].jsonKey, "to")
    }

    func testNoParams() {
        let methods = parseMethods("""
        final class S {
            func reset() {}
        }
        """)

        XCTAssertEqual(methods.count, 1)
        XCTAssertEqual(methods[0].name, "reset")
        XCTAssertEqual(methods[0].params.count, 0)
        XCTAssertNil(methods[0].returnType)
    }

    func testReturnType() {
        let methods = parseMethods("""
        final class S {
            func count() -> Int { 0 }
            func lookup(name: String) -> [String: Any]? { nil }
        }
        """)

        XCTAssertEqual(methods.count, 2)
        XCTAssertEqual(methods[0].returnType, "Int")
        XCTAssertEqual(methods[1].returnType, "[String: Any]?")
    }

    func testMultipleKeywordLabels() {
        let methods = parseMethods("""
        final class S {
            func session(for bookID: String, in library: String) -> String? { nil }
        }
        """)

        XCTAssertEqual(methods.count, 1)
        let m = methods[0]
        XCTAssertEqual(m.params.count, 2)

        XCTAssertEqual(m.params[0].label, "for")
        XCTAssertEqual(m.params[0].internalName, "bookID")
        XCTAssertEqual(m.params[1].label, "in")
        XCTAssertEqual(m.params[1].internalName, "library")
    }

    // MARK: - extractMethods: skipping

    func testSkipsUnlabeledParam() {
        let methods = parseMethods("""
        final class S {
            func remove(_ index: Int) {}
            func visible(name: String) {}
        }
        """)

        XCTAssertEqual(methods.count, 1)
        XCTAssertEqual(methods[0].name, "visible")
    }

    func testSkipsPrivate() {
        let methods = parseMethods("""
        final class S {
            private func helper() {}
            func visible() {}
        }
        """)

        XCTAssertEqual(methods.count, 1)
        XCTAssertEqual(methods[0].name, "visible")
    }

    func testSkipsStatic() {
        let methods = parseMethods("""
        final class S {
            static func factory() -> S { S() }
            func instance() {}
        }
        """)

        XCTAssertEqual(methods.count, 1)
        XCTAssertEqual(methods[0].name, "instance")
    }

    // MARK: - generateAgentCall: code generation

    func testCallGenSimpleLabel() {
        let actual = generateCall("""
        final class S {
            func addTodo(title: String) {}
        }
        """)

        let expected = expect { b in
            b.line(#"case "addTodo":"#)
            b.indented {
                b.line(#"guard let title = params["title"] as? String else { return .error("missing param: title (String)") }"#)
                b.line("addTodo(title: title)")
                b.line("return .value(nil)")
            }
        }

        XCTAssertEqual(actual, expected)
    }

    func testCallGenKeywordLabel() {
        let actual = generateCall("""
        final class S {
            func book(for bookID: String) -> [String: Any]? { nil }
        }
        """)

        let expected = expect { b in
            b.line(#"case "book":"#)
            b.indented {
                b.line(#"guard let bookID = params["for"] as? String else { return .error("missing param: for (String)") }"#)
                b.line("let result = book(for: bookID)")
                b.line("return .value(result)")
            }
        }

        XCTAssertEqual(actual, expected)
    }

    func testCallGenMixedLabels() {
        let actual = generateCall("""
        final class S {
            func move(from source: Int, to destination: Int) {}
        }
        """)

        let expected = expect { b in
            b.line(#"case "move":"#)
            b.indented {
                b.line(#"guard let source = (params["from"] as? NSNumber)?.intValue else { return .error("missing param: from (Int)") }"#)
                b.line(#"guard let destination = (params["to"] as? NSNumber)?.intValue else { return .error("missing param: to (Int)") }"#)
                b.line("move(from: source, to: destination)")
                b.line("return .value(nil)")
            }
        }

        XCTAssertEqual(actual, expected)
    }

    func testCallGenNoParams() {
        let actual = generateCall("""
        final class S {
            func reset() {}
        }
        """)

        let expected = expect { b in
            b.line(#"case "reset":"#)
            b.indented {
                b.line("reset()")
                b.line("return .value(nil)")
            }
        }

        XCTAssertEqual(actual, expected)
    }

    func testCallGenCodableReturn() {
        let actual = generateCall("""
        final class S {
            func getStats() -> Stats { Stats() }
        }
        """)

        let expected = expect { b in
            b.line(#"case "getStats":"#)
            b.indented {
                b.line("let result = getStats()")
                b.line("return .value(__tapEncode(result))")
            }
        }

        XCTAssertEqual(actual, expected)
    }

    func testCallGenCodableParam() {
        let actual = generateCall("""
        final class S {
            func moveTo(point: Point) {}
        }
        """)

        let expected = expect { b in
            b.line(#"case "moveTo":"#)
            b.indented {
                b.line(#"guard let pointRaw = params["point"], let point: Point = __tapDecode(pointRaw) else { return .error("cannot decode param: point (Point)") }"#)
                b.line("moveTo(point: point)")
                b.line("return .value(nil)")
            }
        }

        XCTAssertEqual(actual, expected)
    }

    func testCallGenMultipleMethods() {
        let actual = generateCall("""
        final class S {
            func reset() {}
            func setName(name: String) {}
        }
        """)

        let expected = expect { b in
            b.line(#"case "reset":"#)
            b.indented {
                b.line("reset()")
                b.line("return .value(nil)")
            }
            b.line(#"case "setName":"#)
            b.indented {
                b.line(#"guard let name = params["name"] as? String else { return .error("missing param: name (String)") }"#)
                b.line("setName(name: name)")
                b.line("return .value(nil)")
            }
        }

        XCTAssertEqual(actual, expected)
    }
}
