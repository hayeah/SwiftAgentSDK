import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftUITapPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SwiftUITapMacro.self,
    ]
}
