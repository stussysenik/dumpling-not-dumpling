import Foundation

enum AppMode: String, CaseIterable {
    case party
    case full
}

struct ClassificationResult {
    let label: String
    let confidence: Float
    let allResults: [(label: String, confidence: Float)]

    var isDumpling: Bool {
        label != "not_dumpling"
    }

    var displayLabel: String {
        isDumpling ? "dumpling." : "not dumpling."
    }

    var dumplingType: String? {
        isDumpling ? label : nil
    }

    var partyConfidence: Float {
        allResults
            .filter { $0.label != "not_dumpling" }
            .reduce(0) { $0 + $1.confidence }
    }

    func secondaryMatches(limit: Int = 2) -> [(label: String, confidence: Float)] {
        Array(allResults
            .filter { $0.label != label }
            .sorted { $0.confidence > $1.confidence }
            .prefix(limit))
    }
}
