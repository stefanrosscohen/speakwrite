import Foundation

/// Tier 1 behavioral features: biometric typing signature.
/// Port of packages/core/src/features/tier1.ts
struct Tier1Features: Codable {
    let flightTimeMean: Double
    let flightTimeStd: Double
    let flightTimeMedian: Double
    let holdTimeMean: Double
    let holdTimeStd: Double
    let digraphCount: Int
    let digraphMatrix: [String: DigraphStats]
    let overlapRatio: Double
    let typingSpeedCpm: Double
}

struct DigraphStats: Codable {
    let count: Int
    let mean: Double
    let stdDev: Double
    let median: Double
    let p10: Double
    let p90: Double
}

private let pauseMaxMs: Double = 30_000
private let holdMaxMs: Double = 1_000
private let minDigraphSamples = 5

private func keyLabel(_ key: String) -> String {
    switch key {
    case " ": return "SPC"
    case "Enter": return "ENT"
    case "Backspace": return "BS"
    case "Tab": return "TAB"
    case "Delete": return "DEL"
    default:
        return key.count == 1 ? key.lowercased() : key
    }
}

func extractTier1(events: [Keystroke]) -> Tier1Features {
    let keydowns = events.filter { $0.eventType == "KeyDown" && !$0.isRepeat }

    // Index keyups by sequence number for hold time lookup
    var keyupsBySeq: [Int: Keystroke] = [:]
    for e in events where e.eventType == "KeyUp" {
        keyupsBySeq[e.sequenceNumber] = e
    }

    var flightTimes: [Double] = []
    var digraphRaw: [String: [Double]] = [:]
    var overlapCount = 0
    var totalPairs = 0

    for i in 0..<(keydowns.count - 1) {
        let ft = keydowns[i + 1].timestampMs - keydowns[i].timestampMs
        guard ft > 0, ft <= pauseMaxMs else { continue }

        flightTimes.append(ft)
        totalPairs += 1

        let c1 = keyLabel(keydowns[i].key)
        let c2 = keyLabel(keydowns[i + 1].key)
        let pair = "\(c1)\u{2192}\(c2)"
        digraphRaw[pair, default: []].append(ft)

        // Check for key overlap (roll typing)
        if let keyup = keyupsBySeq[keydowns[i].sequenceNumber + 1],
           keyup.timestampMs > keydowns[i + 1].timestampMs {
            overlapCount += 1
        }
    }

    // Hold times
    var holdTimes: [Double] = []
    for kd in keydowns {
        if let ku = keyupsBySeq[kd.sequenceNumber + 1] {
            let ht = ku.timestampMs - kd.timestampMs
            if ht >= 0, ht <= holdMaxMs {
                holdTimes.append(ht)
            }
        }
    }

    // Digraph statistics (only for pairs with >= minDigraphSamples)
    var digraphMatrix: [String: DigraphStats] = [:]
    for (pair, samples) in digraphRaw where samples.count >= minDigraphSamples {
        digraphMatrix[pair] = DigraphStats(
            count: samples.count,
            mean: Stats.mean(samples),
            stdDev: Stats.stdDev(samples),
            median: Stats.median(samples),
            p10: Stats.percentile(samples, p: 10),
            p90: Stats.percentile(samples, p: 90)
        )
    }

    // Typing speed (characters per minute)
    let durationMs: Double
    if keydowns.count >= 2 {
        durationMs = keydowns.last!.timestampMs - keydowns.first!.timestampMs
    } else {
        durationMs = 0
    }
    let typingSpeedCpm = durationMs > 0
        ? (Double(keydowns.count) / durationMs) * 60_000
        : 0

    return Tier1Features(
        flightTimeMean: Stats.mean(flightTimes),
        flightTimeStd: Stats.stdDev(flightTimes),
        flightTimeMedian: Stats.median(flightTimes),
        holdTimeMean: Stats.mean(holdTimes),
        holdTimeStd: Stats.stdDev(holdTimes),
        digraphCount: digraphMatrix.count,
        digraphMatrix: digraphMatrix,
        overlapRatio: totalPairs > 0 ? Double(overlapCount) / Double(totalPairs) : 0,
        typingSpeedCpm: typingSpeedCpm
    )
}
