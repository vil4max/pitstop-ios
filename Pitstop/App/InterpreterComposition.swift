import Foundation

/// Which interpreters the interpreted Remember path asks, and the version analytics reports for
/// them (ADR 0027).
enum InterpreterComposition: Equatable, Sendable {
    case ruleBased
    /// The rules first; Foundation Models only when the rules find no meaning.
    case ruleBasedThenFoundationModels

    init(arguments: [String]) {
        #if DEBUG
            if arguments.contains(AppEnvironment.foundationModelsArgument) {
                self = .ruleBasedThenFoundationModels
                return
            }
        #endif
        self = .ruleBased
    }

    var interpreter: any SemanticInterpreting {
        switch self {
        case .ruleBased:
            RuleBasedInterpreter()
        case .ruleBasedThenFoundationModels:
            // Rules first: they are deterministic, instant, and cover Russian and Ukrainian, which the
            // model does not support; the model can only add meaning the rules did not find.
            InterpreterChain([RuleBasedInterpreter(), FoundationModelsInterpreter()])
        }
    }

    var version: InterpreterVersion {
        switch self {
        case .ruleBased: .ruleBasedV1
        case .ruleBasedThenFoundationModels: .ruleBasedThenFoundationModelsV1
        }
    }
}
