import SwiftSyntax
import SwiftSyntaxMacros

public struct AgentSDKMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let className = type.trimmedDescription

        // Extract properties and methods from the class declaration
        let properties = extractProperties(from: declaration)
        let methods = extractMethods(from: declaration)

        let getBody = generateAgentGet(properties: properties)
        let setBody = generateAgentSet(properties: properties)
        let callBody = generateAgentCall(methods: methods)
        let snapshotBody = generateAgentSnapshot(properties: properties)

        let extensionDecl: DeclSyntax = """
        extension \(raw: className): AgentDispatchable {
            func __agentGet(_ path: String) -> AgentResult {
                let (head, tail) = AgentPath.split(path)
                switch head {
        \(raw: getBody)
                default: return .error("unknown property: \\(head)")
                }
            }

            func __agentSet(_ path: String, value: Any?) -> AgentResult {
                let (head, tail) = AgentPath.split(path)
                switch head {
        \(raw: setBody)
                default: return .error("unknown property: \\(head)")
                }
            }

            func __agentCall(_ method: String, params: [String: Any]) -> AgentResult {
                switch method {
        \(raw: callBody)
                default: return .error("unknown method: \\(method)")
                }
            }

            func __agentSnapshot() -> [String: Any] {
                return [
        \(raw: snapshotBody)
                ]
            }
        }
        """

        guard let extensionSyntax = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        return [extensionSyntax]
    }
}

// MARK: - Property Extraction

struct PropertyInfo {
    let name: String
    let typeStr: String
    let category: PropertyCategory
    let isReadOnly: Bool // let, computed, or no setter
}

enum PropertyCategory {
    case primitive(String)       // String, Int, Double, Bool
    case optionalPrimitive(String) // String?, Int?, etc.
    case array(String)           // [Foo]
    case childState(String)      // any other single identifier — assume AgentDispatchable
    case unsupported
}

struct MethodInfo {
    let name: String
    let params: [(label: String, type: String)]
    let returnType: String? // nil = Void
}

private let primitiveTypes: Set<String> = ["String", "Int", "Double", "Bool"]

func extractProperties(from declaration: some DeclGroupSyntax) -> [PropertyInfo] {
    var results: [PropertyInfo] = []

    for member in declaration.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

        // Skip static
        if varDecl.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
            continue
        }
        // Skip private/fileprivate
        if varDecl.modifiers.contains(where: { $0.name.text == "private" || $0.name.text == "fileprivate" }) {
            continue
        }

        let isLet = varDecl.bindingSpecifier.text == "let"

        for binding in varDecl.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }

            // Skip if no type annotation
            guard let typeAnnotation = binding.typeAnnotation else { continue }
            let typeStr = typeAnnotation.type.trimmedDescription

            // Check if computed (has accessor block with get but no initializer)
            let isComputed = binding.accessorBlock != nil && binding.initializer == nil

            let isReadOnly = isLet || isComputed
            let category = categorizeType(typeStr)

            results.append(PropertyInfo(
                name: name,
                typeStr: typeStr,
                category: category,
                isReadOnly: isReadOnly
            ))
        }
    }

    return results
}

func categorizeType(_ typeStr: String) -> PropertyCategory {
    // Check primitives
    if primitiveTypes.contains(typeStr) {
        return .primitive(typeStr)
    }

    // Check optional primitives: "String?", "Int?", etc.
    if typeStr.hasSuffix("?") {
        let base = String(typeStr.dropLast())
        if primitiveTypes.contains(base) {
            return .optionalPrimitive(base)
        }
        // Optional non-primitive — skip for now
        return .unsupported
    }

    // Check arrays: "[Foo]"
    if typeStr.hasPrefix("[") && typeStr.hasSuffix("]") && !typeStr.contains(":") {
        let elementType = String(typeStr.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        return .array(elementType)
    }

    // Single identifier — assume child state (AgentDispatchable at runtime)
    // Must be a simple identifier (no generics, no dots, no brackets)
    let isSimpleIdent = typeStr.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    if isSimpleIdent && !typeStr.isEmpty {
        return .childState(typeStr)
    }

    return .unsupported
}

func extractMethods(from declaration: some DeclGroupSyntax) -> [MethodInfo] {
    var results: [MethodInfo] = []

    for member in declaration.memberBlock.members {
        guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

        // Skip static/class
        if funcDecl.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
            continue
        }
        // Skip private/fileprivate
        if funcDecl.modifiers.contains(where: { $0.name.text == "private" || $0.name.text == "fileprivate" }) {
            continue
        }

        let name = funcDecl.name.text

        // Skip init/deinit (init won't appear as FunctionDeclSyntax, but just in case)
        if name == "init" || name == "deinit" { continue }

        // Extract params — all must have labels
        var params: [(label: String, type: String)] = []
        var allSupported = true

        for param in funcDecl.signature.parameterClause.parameters {
            let label = param.firstName.text
            if label == "_" {
                allSupported = false
                break
            }

            guard let typeStr = paramTypeString(param.type) else {
                allSupported = false
                break
            }

            params.append((label: label, type: typeStr))
        }

        if !allSupported { continue }

        let returnType = funcDecl.signature.returnClause?.type.trimmedDescription

        results.append(MethodInfo(name: name, params: params, returnType: returnType))
    }

    return results
}

func paramTypeString(_ type: TypeSyntax) -> String? {
    return type.trimmedDescription
}

// MARK: - Code Generation

func generateAgentGet(properties: [PropertyInfo]) -> String {
    var cases: [String] = []

    for prop in properties {
        switch prop.category {
        case .primitive, .optionalPrimitive:
            cases.append("""
                        case "\(prop.name)": return .value(\(prop.name))
            """)

        case .array(let elementType):
            if primitiveTypes.contains(elementType) {
                // Primitive array — return directly
                cases.append("""
                        case "\(prop.name)":
                            guard let tail else { return .value(\(prop.name)) }
                            let (indexStr, rest) = AgentPath.split(tail)
                            guard let index = Int(indexStr), index >= 0, index < \(prop.name).count else {
                                return .error("index out of bounds: \\(indexStr) (count: \\(\(prop.name).count))")
                            }
                            guard rest == nil else { return .error("cannot traverse into primitive array element") }
                            return .value(\(prop.name)[index])
                """)
            } else {
                // Object array — support traversal
                cases.append("""
                        case "\(prop.name)":
                            guard let tail else {
                                return .value(\(prop.name).compactMap { ($0 as? AgentDispatchable)?.__agentSnapshot() })
                            }
                            let (indexStr, rest) = AgentPath.split(tail)
                            guard let index = Int(indexStr), index >= 0, index < \(prop.name).count else {
                                return .error("index out of bounds: \\(indexStr) (count: \\(\(prop.name).count))")
                            }
                            guard let rest else {
                                return .value((\(prop.name)[index] as? AgentDispatchable)?.__agentSnapshot())
                            }
                            return (\(prop.name)[index] as? AgentDispatchable)?.__agentGet(rest) ?? .error("not dispatchable: \(prop.name)[]")
                """)
            }

        case .childState:
            cases.append("""
                        case "\(prop.name)":
                            guard let tail else {
                                return .value((\(prop.name) as? AgentDispatchable)?.__agentSnapshot())
                            }
                            return (\(prop.name) as? AgentDispatchable)?.__agentGet(tail) ?? .error("not dispatchable: \(prop.name)")
            """)

        case .unsupported:
            continue
        }
    }

    return cases.joined(separator: "\n")
}

func generateAgentSet(properties: [PropertyInfo]) -> String {
    var cases: [String] = []

    for prop in properties {
        if prop.isReadOnly { continue }

        switch prop.category {
        case .primitive(let typeName):
            let cast = castExpression(for: typeName, from: "value")
            cases.append("""
                        case "\(prop.name)":
                            guard let v = \(cast) else { return .error("type mismatch: \(prop.name) expects \(typeName)") }
                            \(prop.name) = v
                            return .value(nil)
            """)

        case .optionalPrimitive(let typeName):
            let cast = castExpression(for: typeName, from: "value")
            cases.append("""
                        case "\(prop.name)":
                            if value == nil || value is NSNull { \(prop.name) = nil; return .value(nil) }
                            guard let v = \(cast) else { return .error("type mismatch: \(prop.name) expects \(typeName)?") }
                            \(prop.name) = v
                            return .value(nil)
            """)

        case .array:
            cases.append("""
                        case "\(prop.name)":
                            guard let tail else { return .error("cannot replace \(prop.name) array directly") }
                            let (indexStr, rest) = AgentPath.split(tail)
                            guard let index = Int(indexStr), index >= 0, index < \(prop.name).count else {
                                return .error("index out of bounds: \\(indexStr)")
                            }
                            guard let rest else { return .error("cannot replace array element directly") }
                            return (\(prop.name)[index] as? AgentDispatchable)?.__agentSet(rest, value: value) ?? .error("not dispatchable: \(prop.name)[]")
            """)

        case .childState:
            cases.append("""
                        case "\(prop.name)":
                            guard let tail else { return .error("cannot replace \(prop.name) object") }
                            return (\(prop.name) as? AgentDispatchable)?.__agentSet(tail, value: value) ?? .error("not dispatchable: \(prop.name)")
            """)

        case .unsupported:
            continue
        }
    }

    return cases.joined(separator: "\n")
}

func generateAgentCall(methods: [MethodInfo]) -> String {
    var cases: [String] = []

    for method in methods {
        var lines: [String] = []
        lines.append("            case \"\(method.name)\":")

        // Generate param extraction
        for param in method.params {
            if primitiveTypes.contains(param.type) {
                let cast = castExpression(for: param.type, from: "params[\"\(param.label)\"]")
                lines.append("                guard let \(param.label) = \(cast) else { return .error(\"missing param: \(param.label) (\(param.type))\") }")
            } else {
                // Codable param — use __agentDecode
                lines.append("                guard let \(param.label)Raw = params[\"\(param.label)\"], let \(param.label): \(param.type) = __agentDecode(\(param.label)Raw) else { return .error(\"cannot decode param: \(param.label) (\(param.type))\") }")
            }
        }

        // Generate call
        let args = method.params.map { "\($0.label): \($0.label)" }.joined(separator: ", ")
        if let returnType = method.returnType {
            lines.append("                let result = \(method.name)(\(args))")
            if isPrimitiveOrDict(returnType) {
                lines.append("                return .value(result)")
            } else {
                // Codable return — use __agentEncode
                lines.append("                return .value(__agentEncode(result))")
            }
        } else {
            lines.append("                \(method.name)(\(args))")
            lines.append("                return .value(nil)")
        }

        cases.append(lines.joined(separator: "\n"))
    }

    return cases.joined(separator: "\n")
}

func generateAgentSnapshot(properties: [PropertyInfo]) -> String {
    var entries: [String] = []

    for prop in properties {
        switch prop.category {
        case .primitive, .optionalPrimitive:
            entries.append("                \"\(prop.name)\": \(prop.name) as Any,")

        case .array(let elementType):
            if primitiveTypes.contains(elementType) {
                entries.append("                \"\(prop.name)\": \(prop.name),")
            } else {
                entries.append("                \"\(prop.name)\": \(prop.name).compactMap { ($0 as? AgentDispatchable)?.__agentSnapshot() },")
            }

        case .childState:
            entries.append("                \"\(prop.name)\": (\(prop.name) as? AgentDispatchable)?.__agentSnapshot() as Any,")

        case .unsupported:
            continue
        }
    }

    return entries.joined(separator: "\n")
}

func isPrimitiveOrDict(_ typeStr: String) -> Bool {
    let base = typeStr.hasSuffix("?") ? String(typeStr.dropLast()) : typeStr
    return primitiveTypes.contains(base) || base == "[String: Any]"
}

func castExpression(for typeName: String, from source: String) -> String {
    switch typeName {
    case "String":
        return "\(source) as? String"
    case "Int":
        return "(\(source) as? NSNumber)?.intValue"
    case "Double":
        return "(\(source) as? NSNumber)?.doubleValue"
    case "Bool":
        return "(\(source) as? NSNumber)?.boolValue"
    default:
        return "\(source) as? \(typeName)"
    }
}
