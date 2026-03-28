import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftAgentSDKPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AgentSDKMacro.self,
    ]
}
