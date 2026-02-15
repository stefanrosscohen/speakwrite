import Foundation
import SwiftData

/// Manages the session lifecycle: start → capture → checkpoint → end.
/// Coordinates keystroke storage, feature extraction, commitment chain, and device attestation.
@Observable
@MainActor
final class SessionService: KeystrokeCaptureDelegate {
    private let modelContext: ModelContext
    private let attestation: DeviceAttestationService

    private(set) var currentSession: Session?
    private(set) var currentDocument: Document?
    private(set) var keystrokeCount: Int = 0
    private(set) var commitmentCount: Int = 0
    private(set) var commitments: [Commitment] = []
    private(set) var sessionActive: Bool = false

    private var keystrokeBuffer: [KeystrokeEvent] = []
    private var allSessionKeystrokes: [Keystroke] = [] // For feature extraction
    private var checkpointTimer: Timer?

    // Checkpoint every 60 seconds of active typing
    private let checkpointIntervalSeconds: TimeInterval = 60

    init(modelContext: ModelContext, attestation: DeviceAttestationService) {
        self.modelContext = modelContext
        self.attestation = attestation
    }

    // MARK: - Session Lifecycle

    func startSession() async throws {
        let document = Document()
        modelContext.insert(document)

        let session = Session(document: document)
        modelContext.insert(session)

        currentDocument = document
        currentSession = session
        keystrokeCount = 0
        commitmentCount = 0
        commitments = []
        keystrokeBuffer = []
        allSessionKeystrokes = []
        sessionActive = true

        // Initialize device attestation and start attested session (triggers Face ID)
        _ = try await attestation.initialize()
        _ = try await attestation.startSession()

        // Start periodic checkpoint timer
        checkpointTimer = Timer.scheduledTimer(withTimeInterval: checkpointIntervalSeconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                try? await self.checkpoint()
            }
        }
    }

    func endSession() async throws {
        checkpointTimer?.invalidate()
        checkpointTimer = nil

        // Final checkpoint with remaining keystrokes
        if !keystrokeBuffer.isEmpty {
            try await checkpoint()
        }

        currentSession?.endedAt = Date()
        currentSession?.status = "completed"
        sessionActive = false

        try modelContext.save()
    }

    // MARK: - KeystrokeCaptureDelegate

    nonisolated func didRecordKeystroke(_ event: KeystrokeEvent) {
        Task { @MainActor in
            self.recordKeystroke(event)
        }
    }

    nonisolated func textDidChange(_ text: String) {
        Task { @MainActor in
            self.updateText(text)
        }
    }

    private func recordKeystroke(_ event: KeystrokeEvent) {
        guard let session = currentSession else { return }

        // Store in SwiftData
        let keystroke = Keystroke(
            session: session,
            eventType: event.eventType,
            key: event.key,
            code: event.code,
            timestampMs: event.timestampMs,
            shiftKey: event.shiftKey,
            ctrlKey: event.ctrlKey,
            altKey: event.altKey,
            metaKey: event.metaKey,
            isRepeat: event.isRepeat,
            isComposing: event.isComposing,
            sequenceNumber: event.sequenceNumber
        )
        modelContext.insert(keystroke)
        allSessionKeystrokes.append(keystroke)

        // Buffer for checkpoint
        keystrokeBuffer.append(event)

        if event.eventType == "KeyDown" {
            keystrokeCount += 1
            session.keystrokeCount = keystrokeCount
        }
    }

    private func updateText(_ text: String) {
        guard let doc = currentDocument else { return }
        doc.contentJSON = text
        doc.wordCount = text.split(separator: " ").count
        doc.updatedAt = Date()
    }

    // MARK: - Checkpoint

    func checkpoint() async throws {
        guard let document = currentDocument else { return }
        guard !allSessionKeystrokes.isEmpty else { return }

        // Extract behavioral features from all keystrokes so far
        let tier1 = extractTier1(events: allSessionKeystrokes)
        let tier2 = extractTier2(events: allSessionKeystrokes)

        // Serialize features to JSON
        let encoder = JSONEncoder()
        let tier1Data = try encoder.encode(tier1)
        let tier2Data = try encoder.encode(tier2)
        let featureData = tier1Data // Use tier1 as the commitment data

        // Generate nonce
        let nonce = SpeakwriteCrypto.randomNonce()

        // Get the previous commitment hash (chain tip)
        let previousHash = commitments.last?.commitmentHash

        // Compute chained commitment hash
        let hash = SpeakwriteCrypto.commitmentHash(
            previous: previousHash,
            nonce: nonce,
            data: featureData
        )

        let nowMs = ProcessInfo.processInfo.systemUptime * 1000

        // Sign with Secure Enclave
        let sig = try await attestation.signCheckpoint(
            commitmentHash: hash,
            sequenceNum: commitmentCount
        )

        // Store commitment
        let commitment = Commitment(
            document: document,
            sequenceNum: commitmentCount,
            commitmentHash: hash,
            previousHash: previousHash,
            nonce: Hex.encode(nonce),
            timestampMs: nowMs,
            commitmentType: "behavioral",
            featureJSON: String(data: tier1Data, encoding: .utf8)
        )
        modelContext.insert(commitment)
        commitments.append(commitment)
        commitmentCount += 1

        // Store feature vector
        let fv = FeatureVector(
            session: currentSession,
            tier1JSON: String(data: tier1Data, encoding: .utf8) ?? "{}",
            tier2JSON: String(data: tier2Data, encoding: .utf8) ?? "{}"
        )
        modelContext.insert(fv)

        // Clear buffer (keep allSessionKeystrokes for cumulative features)
        keystrokeBuffer = []

        try modelContext.save()
    }
}
