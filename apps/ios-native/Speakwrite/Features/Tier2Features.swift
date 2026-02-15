import Foundation

/// Tier 2 behavioral features: error patterns.
/// Port of packages/core/src/features/tier2.ts
struct Tier2Features: Codable {
    let backspaceRate: Double
    let deleteRate: Double
    let errorBurstCount: Int
    let meanErrorBurstLength: Double
    let immediateCorrectionRatio: Double
    let revisionRatio: Double
}

func extractTier2(events: [Keystroke]) -> Tier2Features {
    let keydowns = events.filter { $0.eventType == "KeyDown" && !$0.isRepeat }

    guard !keydowns.isEmpty else {
        return Tier2Features(
            backspaceRate: 0, deleteRate: 0,
            errorBurstCount: 0, meanErrorBurstLength: 0,
            immediateCorrectionRatio: 0, revisionRatio: 0
        )
    }

    let total = keydowns.count
    let backspaceCount = keydowns.filter { $0.key == "Backspace" }.count
    let deleteCount = keydowns.filter { $0.key == "Delete" }.count
    let correctionCount = backspaceCount + deleteCount

    var bursts: [Int] = []
    var currentBurst = 0
    var immediateCorrections = 0

    for i in 0..<keydowns.count {
        let kd = keydowns[i]
        if kd.key == "Backspace" || kd.key == "Delete" {
            currentBurst += 1

            // Immediate correction: backspace right after a character key
            if i > 0 {
                let prev = keydowns[i - 1]
                if prev.key != "Backspace" && prev.key != "Delete" && prev.key.count == 1 {
                    let gap = kd.timestampMs - prev.timestampMs
                    if gap < 500 {
                        immediateCorrections += 1
                    }
                }
            }
        } else {
            if currentBurst > 0 {
                bursts.append(currentBurst)
                currentBurst = 0
            }
        }
    }
    if currentBurst > 0 {
        bursts.append(currentBurst)
    }

    let meanBurstLen = bursts.isEmpty
        ? 0.0
        : Double(bursts.reduce(0, +)) / Double(bursts.count)

    return Tier2Features(
        backspaceRate: Double(backspaceCount) / Double(total),
        deleteRate: Double(deleteCount) / Double(total),
        errorBurstCount: bursts.count,
        meanErrorBurstLength: meanBurstLen,
        immediateCorrectionRatio: correctionCount > 0
            ? Double(immediateCorrections) / Double(correctionCount)
            : 0,
        revisionRatio: Double(correctionCount) / Double(total)
    )
}
