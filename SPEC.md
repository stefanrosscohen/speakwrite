# Speakwrite Protocol Specification

**Version:** 0.1-draft
**Status:** Working Draft
**Date:** 2026-02-13
**Authors:** Stefan Cohen
**License:** CC BY-SA 4.0

---

## 1. Abstract

This document specifies Speakwrite, an open protocol for establishing probabilistic evidence that a given document was composed through physical human keystroke activity. The protocol combines three independent mechanisms: (1) continuous behavioral observation of keystroke dynamics during composition, (2) cryptographic signing that binds the observed behavioral evidence to the resulting document, and (3) zero-knowledge personhood verification via the World ID protocol to provide Sybil resistance without exposing the author's identity.

Speakwrite does not claim to prove that a document's *ideas* originated from a human, nor does it claim to prove that no artificial intelligence was consulted during composition. It provides forensic evidence — of tunable strength — that a specific document was produced through a physical typing process exhibiting characteristics consistent with human motor behavior, and that this process was performed by a unique person who has not registered multiple authorship identities.

The protocol is designed to be open source, decentralized, and verifiable by any third party without reliance on a central authority.

---

## 2. Introduction

### 2.1 Motivation

The proliferation of large language models capable of producing fluent, coherent, and topically sophisticated text has created a fundamental epistemic problem: for an increasing range of written content, it is no longer possible to determine from the output alone whether a human or a machine produced it.

This is not a temporary gap that better detection will close. Output-analysis approaches to AI-generated text detection — whether statistical classifiers, watermarking schemes, or stylometric analysis — are engaged in an inherently asymmetric arms race. Each improvement in detection capability becomes a training signal for the next generation of models. The detector must be correct in every case; the generator needs only to evade detection once. Empirically, the false-positive rates of current AI text detectors render them unreliable for high-stakes determinations, and there is no theoretical basis for believing this will change as model capabilities improve.

Speakwrite adopts a fundamentally different approach. Rather than analyzing the *output* to infer its origin, it instruments the *process* of composition and produces a cryptographic attestation binding the observed process to the resulting document. The core insight is that human typing is a complex motor behavior with stochastic properties that are both individually distinctive and categorically different from programmatic text generation. By capturing and attesting to these properties at composition time, we shift the problem from the intractable domain of output analysis to the more tractable domain of process verification.

This shift is not without its own limitations — a human may physically type words that were dictated by an AI, for instance — but it raises the cost and complexity of deception by orders of magnitude compared to simply prompting a language model.

The need for such a protocol is acute across multiple domains:

- **Journalism and publishing:** Establishing that reported content was composed by a human author, not generated from a prompt.
- **Academic integrity:** Providing evidence that submitted work reflects the student's own writing process.
- **Legal and regulatory filings:** Attesting that documents were drafted through human deliberation.
- **Civic discourse:** Countering the deployment of AI-generated content at scale in political contexts.
- **Creative works:** Establishing provenance for written works where human authorship carries economic or cultural value.

### 2.2 Design Goals

The protocol is designed to satisfy the following properties:

1. **Prove human keystroke origin.** The protocol produces evidence that a document was composed through a physical typing process consistent with human motor behavior. It attests to the *process*, not to the absence of AI involvement in ideation or planning.

2. **Privacy-preserving.** No raw biometric data — including raw keystroke timing sequences — is exposed to verifiers or stored in any public record. All behavioral evidence is transformed into aggregate statistical features and committed via zero-knowledge mechanisms before any data leaves the author's device.

3. **Cryptographically verifiable.** Any third party holding a signed Speakwrite attestation can verify its integrity, the binding between the behavioral evidence and the document, and the personhood claim, without requiring access to any proprietary system or trusted third party beyond the World ID verification infrastructure.

4. **Sybil-resistant.** Through integration with the World ID protocol's zero-knowledge proof of personhood, the protocol ensures that a single human cannot create multiple independent authorship identities to fabricate a history of "verified" human writing. This prevents the accumulation of fraudulent trust over time.

5. **Progressive trust.** A single attestation provides weak evidence. A corpus of attestations from the same pseudonymous identity, exhibiting consistent behavioral characteristics across documents and over time, provides substantially stronger evidence. The protocol is designed so that trust accumulates monotonically with an author's publication history.

6. **Open source and decentralized.** The protocol specification is public. Reference implementations are open source. Verification requires no central authority, no API keys, and no trusted intermediary. Any party can implement a compliant observer, signer, or verifier.

### 2.3 Non-Goals

Intellectual honesty about the boundaries of this protocol is a design requirement, not an afterthought. Speakwrite explicitly does **not** claim to provide the following:

- **Proof of original thought.** The protocol attests that keystrokes occurred. It cannot determine whether the ideas expressed through those keystrokes originated in the author's mind, were copied from a source, or were suggested by an AI assistant and then manually typed.

- **Proof that no AI was consulted.** An author may use a language model to generate an outline, draft paragraphs, or suggest phrasings, and then retype the output manually. The protocol will produce a valid attestation for this process. The behavioral features may differ statistically from fully original composition — and a sophisticated verifier may note this — but the protocol does not and cannot guarantee AI-free ideation.

- **Prevention of human transcription.** The most fundamental limitation: a human reading AI-generated text from one screen and typing it into an Speakwrite-instrumented editor will produce a valid attestation. This is the irreducible lower bound on what process-based verification can achieve. We discuss mitigations (behavioral anomaly detection in transcription patterns) in Section 3.4, but acknowledge that a determined, skilled transcriber may defeat them.

- **Mathematical proof of humanness.** The protocol produces *forensic evidence* — probabilistic, defeasible, and subject to interpretation. It is not a mathematical proof. There is no formal proof system in which "this document was typed by a human" can be established with cryptographic certainty. The protocol's value lies in making forgery expensive and detectable, not in making it impossible.

- **Content authenticity or accuracy.** The protocol says nothing about whether the content of a document is true, accurate, well-reasoned, or original. A human-typed document full of fabrications will receive the same attestation as a carefully researched one.

- **Real-time verification.** The protocol operates on completed (or checkpointed) documents. It does not provide streaming proof of human authorship during the act of composition, though future extensions may address this.

### 2.4 Protocol Overview

Speakwrite operates in three sequential phases:

**Phase 1: Capture.** A client-side software component (the *Observer*) instruments the author's text editor or input environment. During composition, the Observer records keystroke event data including key identity, timing (key-down and key-up timestamps), and inter-key intervals. The Observer also records metadata about the editing process: cursor movements, deletions, insertions, pauses, and revision patterns. All data remains local to the author's device. At the conclusion of a writing session (or at periodic checkpoints), the Observer computes a *Behavioral Feature Vector* (BFV) — a fixed-dimensional statistical summary of the keystroke dynamics — and generates a *Composition Trace Hash* (CTH) that commits to the sequence of editing operations without revealing them.

**Phase 2: Sign.** The author's client software constructs an *Authorship Attestation* — a structured data object containing: (a) a cryptographic hash of the final document, (b) the Behavioral Feature Vector, (c) the Composition Trace Hash, (d) a zero-knowledge proof of personhood from the World ID protocol, and (e) a digital signature over the entire attestation using the author's persistent pseudonymous signing key. The attestation binds the document, the behavioral evidence, the personhood proof, and the author's pseudonymous identity into a single, tamper-evident object.

**Phase 3: Verify.** Any third party (the *Verifier*) holding the document and its associated attestation can perform the following checks: (a) verify the document hash matches the attested hash, (b) verify the digital signature over the attestation, (c) verify the zero-knowledge personhood proof, (d) evaluate the Behavioral Feature Vector against known distributions of human keystroke dynamics, and (e) optionally, compare the BFV against the author's historical BFV profile for consistency. The Verifier produces a *confidence assessment* — not a binary accept/reject — reflecting the strength of the evidence.

### 2.5 Terminology

The following terms are used throughout this specification with the precise meanings defined here.

**Attestation.** A signed data structure binding a document hash, behavioral evidence, personhood proof, and author identity. The fundamental output of the protocol. Formally, an attestation is a tuple $A = (H_d, \text{BFV}, \text{CTH}, \pi_{wid}, \sigma, pk, t)$ where the components are defined below.

**Author.** The human individual who physically composes a document through a keystroke-driven process. Denoted $\mathcal{A}$ in formal notation.

**Behavioral Feature Vector (BFV).** A fixed-dimensional real-valued vector $\mathbf{b} \in \mathbb{R}^n$ summarizing the statistical properties of keystroke dynamics observed during composition. The BFV is derived from raw timing data but does not contain raw timing data. Its dimensionality $n$ and the specific features it encodes are defined in Section 5 (forthcoming).

**Composition Trace Hash (CTH).** A cryptographic commitment to the ordered sequence of editing operations (insertions, deletions, cursor movements) that produced the final document. Formally, $\text{CTH} = H(\text{op}_1 \| \text{op}_2 \| \ldots \| \text{op}_m)$ where each $\text{op}_i$ is an encoded editing operation and $H$ is a collision-resistant hash function. The CTH allows an author to later prove (if they choose) that a specific editing sequence occurred, without revealing the sequence by default.

**Confidence Score.** A scalar value $c \in [0, 1]$ produced by a Verifier, representing the assessed probability that the attestation reflects genuine human composition. The protocol does not mandate a specific confidence threshold for acceptance; this is a policy decision left to the Verifier.

**Document.** The final written content for which authorship evidence is being produced. Denoted $D$. The protocol treats the document as an opaque byte string; it is agnostic to format, encoding, or content.

**Document Hash.** The output of applying a collision-resistant hash function to the document: $H_d = H(D)$. The specific hash function is specified in the attestation metadata.

**Nonce.** A unique, unpredictable value used exactly once in a protocol execution to prevent replay attacks. Denoted $\eta$.

**Observer.** The client-side software component responsible for capturing keystroke dynamics and editing operations during composition. The Observer is part of the trusted computing base. Denoted $\mathcal{O}$.

**Personhood Proof.** A zero-knowledge proof $\pi_{wid}$ produced via the World ID protocol, demonstrating that the author is a unique human who has not previously registered a different Speakwrite identity. The proof reveals no identifying information about the author.

**Pseudonymous Author Identity.** A persistent public key $pk$ associated with the author, unlinkable to the author's real-world identity or World ID enrollment data. The same $pk$ is used across multiple attestations to enable progressive trust accumulation.

**Replay Attack.** An attack in which a valid attestation from one composition session is reused to falsely attest to a different document.

**Session.** A single, contiguous period of composition activity bounded by an explicit start event (the author opens or resumes a document in an instrumented editor) and an explicit end event (the author finalizes the document or creates a checkpoint). Denoted $S$.

**Signing Key.** An asymmetric key pair $(sk, pk)$ where $sk$ is the author's private signing key (stored locally, never transmitted) and $pk$ is the corresponding public verification key (included in attestations and published as the author's pseudonymous identity).

**Sybil Attack.** An attack in which a single adversary creates multiple pseudonymous identities to fabricate independent authorship histories, thereby accumulating fraudulent progressive trust.

**Verifier.** Any party that evaluates an attestation to assess the evidence for human authorship. Denoted $\mathcal{V}$. The Verifier is not trusted by the protocol; the protocol's security properties hold regardless of the Verifier's behavior.

**World ID.** The decentralized identity and proof-of-personhood protocol developed by the Worldcoin Foundation, used by Speakwrite for Sybil resistance. The protocol relies on World ID's Proof of Personhood primitive, which allows an individual to prove they are a unique human without revealing their identity.

**Zero-Knowledge Proof (ZKP).** A cryptographic proof that demonstrates the truth of a statement without revealing any information beyond the truth of the statement itself.

---

## 3. Threat Model

### 3.1 System Model

The protocol involves three classes of participants:

**Author ($\mathcal{A}$).** A human individual who composes written documents using a keystroke-driven input method. The Author operates an Observer on their local device and holds a signing key pair $(sk, pk)$. The Author has completed World ID enrollment and possesses the ability to generate personhood proofs. The Author is assumed to be *honest but potentially compromised* — that is, the protocol must produce valid results when the Author behaves honestly, but the security analysis must consider scenarios in which the Author's device or credentials are misused.

**Verifier ($\mathcal{V}$).** Any party that receives a document $D$ together with an attestation $A$ and evaluates the evidence for human authorship. The Verifier is *untrusted* — the protocol does not depend on the Verifier behaving honestly, and a dishonest Verifier should gain no information beyond what the attestation intentionally reveals. Multiple independent Verifiers may evaluate the same attestation and reach different confidence assessments; this is by design.

**Adversary ($\mathcal{E}$).** A party whose goal is to produce a document $D^*$ and a valid-appearing attestation $A^*$ such that a Verifier assigns a high confidence score, despite $D^*$ not having been composed through genuine human keystroke activity. Adversaries are classified by capability in Section 3.3.

**World ID Oracle ($\mathcal{W}$).** The external system providing proof-of-personhood verification. Modeled as a trusted third party for the property that each human can obtain at most one credential. The protocol's Sybil resistance degrades if this assumption is violated.

**Communication Model.** The protocol assumes that the Author can publish attestations through any channel (including untrusted channels). Attestations are self-verifying; their integrity does not depend on the integrity of the communication channel. The protocol does not require any real-time communication between Author and Verifier during composition.

### 3.2 Trust Assumptions

The protocol's security rests on the following explicit assumptions. If any assumption is violated, the corresponding security property may be degraded or lost.

**TA-1: Observer Integrity.** The Observer software running on the Author's device faithfully records keystroke events and computes the Behavioral Feature Vector and Composition Trace Hash correctly. This is the most critical trust assumption and the hardest to enforce. Mitigations (remote attestation, reproducible builds, hardware-backed attestation) are discussed in Section 3.4, but in the base protocol, the Observer is part of the trusted computing base.

**TA-2: World ID Enrollment Fidelity.** The World ID system correctly enforces the property that each unique human can obtain at most one World ID credential. If the World ID Sybil resistance is compromised (e.g., through biometric spoofing at enrollment), the Speakwrite Sybil resistance degrades correspondingly.

**TA-3: Author Key Custody.** The Author's private signing key $sk$ is stored securely on the Author's device and is not accessible to any other party. If $sk$ is compromised, the adversary can produce attestations that appear to originate from the Author, but cannot forge behavioral evidence without also compromising the Observer.

**TA-4: Cryptographic Hardness.** Standard cryptographic assumptions hold: the hash function $H$ is collision-resistant and preimage-resistant; the digital signature scheme is existentially unforgeable under chosen-message attack (EUF-CMA); the zero-knowledge proof system is complete, sound, and zero-knowledge.

**TA-5: Clock Integrity.** The Author's device maintains a monotonic clock with sufficient resolution (millisecond or better) and the clock is not subject to adversarial manipulation during a composition session. Relative timing (inter-key intervals) is more critical than absolute timestamps; the protocol is designed to tolerate reasonable clock drift but not adversarial clock manipulation.

**TA-6: Behavioral Distinguishability.** Human keystroke dynamics are statistically distinguishable from programmatically generated keystroke dynamics with nontrivial probability. This is an empirical assumption supported by decades of keystroke dynamics research, but it is not a mathematical certainty for all adversary sophistication levels. The protocol's value degrades gracefully as adversary simulation capability improves.

### 3.3 Adversary Model

We define four classes of adversary in order of increasing sophistication. Each subsequent class subsumes the capabilities of the previous classes.

#### 3.3.1 Class I: Passive Observer

**Capabilities.** The Passive Observer can intercept and read any published attestation and its associated document. The adversary can analyze the Behavioral Feature Vector, the Composition Trace Hash, and all public metadata. The adversary has access to a corpus of legitimate attestations from multiple authors.

**Goals.** Extract private information about the Author (real-world identity, raw biometric data) from published attestations. Link multiple pseudonymous attestations to the same Author across different contexts where the Author intended unlinkability. Build behavioral profiles that could be used for impersonation.

**Threat Level.** This class tests the *privacy preservation* property. The protocol must ensure that attestations reveal no more than the intended information, even to a computationally unbounded observer.

#### 3.3.2 Class II: Active Forger

**Capabilities.** In addition to Class I capabilities, the Active Forger can generate arbitrary documents and attempt to produce valid-appearing attestations for them. The adversary has access to AI text generation systems and can write software to produce synthetic keystroke timing data. The adversary can modify open-source Observer software. The adversary operates a single identity (one World ID credential).

**Goals.** Produce AI-generated documents with attestations that Verifiers accept as human-composed. The adversary seeks to minimize their effort per forged attestation.

**Threat Level.** This class tests the *integrity* and *forgery cost escalation* properties. The protocol must ensure that producing a convincing forgery requires substantially more effort than simply prompting a language model.

#### 3.3.3 Class III: Sophisticated Simulator

**Capabilities.** In addition to Class II capabilities, the Sophisticated Simulator has access to detailed research on human keystroke dynamics, can build generative models of human typing behavior, and can produce synthetic keystroke sequences that match known statistical distributions of human typing. The adversary can invest significant computational resources in simulation. The adversary may have collected keystroke data from real humans (with or without consent) to train simulation models.

**Goals.** Same as Class II, but the adversary is willing to invest significant resources and seeks to defeat statistical analysis of the Behavioral Feature Vector.

**Threat Level.** This class tests the *depth* of the behavioral analysis. The protocol must employ sufficiently rich behavioral features that simulation remains detectable even against a well-resourced adversary. The protocol acknowledges (see Section 3.6) that a sufficiently advanced simulator may eventually become indistinguishable from a human author for any fixed set of behavioral features.

#### 3.3.4 Class IV: Human Transcriber

**Capabilities.** In addition to all previous capabilities, the Human Transcriber employs an actual human to physically type AI-generated content into an instrumented editor. The typing process is genuine human keystroke activity; only the intellectual origin of the content is artificial.

**Goals.** Produce attestations that are indistinguishable from genuine human-composed documents because the keystroke data *is* genuine human keystroke data.

**Threat Level.** This class represents the **fundamental limitation** of any process-based verification system. Since the physical typing process is genuinely human, the keystroke dynamics will be genuinely human. The protocol's mitigations for this class are necessarily weaker and more heuristic: detecting patterns consistent with transcription (unusually regular pacing, absence of revision, reduced pauses for thought) rather than detecting non-human behavior. The protocol is honest that this class of adversary cannot be reliably defeated by process observation alone.

### 3.4 Attack Surface Analysis

The following taxonomy enumerates known attack vectors, their feasibility, and the protocol's mitigations.

#### 3.4.1 Paste Injection

| Property | Value |
|---|---|
| **Adversary Class** | II (Active Forger) |
| **Description** | The adversary generates text via AI, copies it to the clipboard, and pastes it into the instrumented editor, hoping the Observer does not distinguish pasting from typing. |
| **Difficulty** | Low |
| **Mitigation** | The Observer records clipboard events (paste operations) as distinct from keystroke events. Pasted content is flagged in the Composition Trace and excluded from BFV computation. The BFV includes the ratio of typed characters to total characters as a feature. A document that is predominantly pasted will have a BFV reflecting minimal genuine keystroke activity, and a Verifier will assign a correspondingly low confidence score. |
| **Residual Risk** | Minimal. This attack is trivially detectable by a compliant Observer. |

#### 3.4.2 Keystroke Scripting (Naive)

| Property | Value |
|---|---|
| **Adversary Class** | II (Active Forger) |
| **Description** | The adversary writes a script that emits synthetic keyboard events at the operating system level, simulating typing with randomized inter-key intervals drawn from a simple distribution (e.g., uniform or Gaussian). |
| **Difficulty** | Low to Moderate |
| **Mitigation** | The BFV includes features that capture higher-order statistical properties of human typing that naive randomization does not reproduce: digraph-specific timing distributions (the interval between specific key pairs varies characteristically for each pair), the correlation between typing speed and error rate, the temporal structure of pauses (human pauses follow power-law distributions correlated with linguistic boundaries), and the micro-structure of key-down/key-up overlap patterns (rollover). Naive scripts produce BFVs that are statistically distinguishable from human distributions on these features. |
| **Residual Risk** | Low against current naive approaches. Effectiveness degrades against more sophisticated scripting (see 3.4.3). |

#### 3.4.3 Keystroke Scripting (Sophisticated)

| Property | Value |
|---|---|
| **Adversary Class** | III (Sophisticated Simulator) |
| **Description** | The adversary builds a generative model of human keystroke dynamics using real human typing data and produces synthetic keystroke sequences that match known statistical properties of human typing, including digraph timing, pause structure, error patterns, and revision behavior. |
| **Difficulty** | High |
| **Mitigation** | The protocol employs a defense-in-depth strategy: (a) the BFV feature set is designed to be high-dimensional, including features that are difficult to model jointly (e.g., the interaction between cognitive load indicators and motor execution variability); (b) progressive trust analysis compares BFVs across an author's corpus — a simulator must maintain consistent behavioral characteristics across many documents, which constrains the simulator's degrees of freedom; (c) the feature set is extensible, allowing the inclusion of new behavioral dimensions as simulation capabilities improve; (d) optional hardware-backed attestation (e.g., TPM-attested input event provenance) can provide additional assurance that events originated from a physical input device. |
| **Residual Risk** | Moderate. A well-resourced adversary with access to sufficient real human typing data can likely produce increasingly convincing simulations. The protocol treats this as an ongoing arms race, but one where the cost asymmetry favors the defender (capturing real behavior is cheap; simulating it convincingly across all feature dimensions is expensive). |

#### 3.4.4 Replay Attacks

| Property | Value |
|---|---|
| **Adversary Class** | II (Active Forger) |
| **Description** | The adversary captures a legitimate attestation from a genuine composition session and attempts to associate it with a different document. |
| **Difficulty** | Low (attempt), Infeasible (success) |
| **Mitigation** | The attestation includes a cryptographic hash of the document $H_d = H(D)$. Any modification to the document invalidates the hash binding. The attestation also includes a Composition Trace Hash that commits to the specific sequence of editing operations that produced the document; this CTH will not match a different document. The attestation is signed with the author's private key, and the signature covers both the document hash and the CTH. |
| **Residual Risk** | Negligible, assuming collision resistance of $H$. |

#### 3.4.5 Behavioral Data Fabrication

| Property | Value |
|---|---|
| **Adversary Class** | II or III |
| **Description** | The adversary modifies the Observer software to emit a fabricated BFV with plausible-looking statistical properties, without any actual keystroke observation occurring. |
| **Difficulty** | Moderate (fabrication), Low (modifying open-source Observer) |
| **Mitigation** | (a) The Composition Trace Hash commits to the editing operation sequence, which must be consistent with both the final document and the BFV — fabricating all three consistently is substantially harder than fabricating the BFV alone. (b) Optional remote attestation of the Observer binary can provide assurance that the software has not been modified. (c) Progressive trust analysis can detect BFVs that are statistically implausible (too perfect, too consistent across documents, or inconsistent with the author's established behavioral profile). (d) The BFV includes internal consistency checks — features that are derived from the same underlying data and must satisfy known mathematical relationships. |
| **Residual Risk** | Moderate. A sufficiently sophisticated adversary can potentially fabricate consistent BFVs, CTHs, and documents. This is mitigated but not eliminated by internal consistency requirements and progressive trust. |

#### 3.4.6 World ID Credential Sharing

| Property | Value |
|---|---|
| **Adversary Class** | II |
| **Description** | A person who has enrolled in World ID shares their credential (or the derived Speakwrite signing key) with another party, enabling the second party to produce attestations under the first party's personhood proof. |
| **Difficulty** | Low (social engineering or coercion), Moderate (technical extraction) |
| **Mitigation** | (a) The World ID credential is designed to be tightly bound to the enrollee and resistant to transfer. (b) The Speakwrite signing key is derived from the World ID credential in a way that makes sharing the signing key equivalent to sharing the World ID credential itself, which is a broader security compromise than just Speakwrite abuse. (c) Progressive trust analysis will detect behavioral inconsistencies if two different humans use the same credential (different people have different typing profiles). (d) The protocol cannot prevent this attack entirely — it is fundamentally a human coordination problem, not a cryptographic one. |
| **Residual Risk** | Moderate. Credential sharing is a known limitation of all identity-based systems. The protocol raises the cost (sharing a World ID credential has consequences beyond Speakwrite) but cannot eliminate it. |

#### 3.4.7 Human Transcription of AI Output

| Property | Value |
|---|---|
| **Adversary Class** | IV (Human Transcriber) |
| **Description** | A human reads AI-generated text from one screen and manually types it into an Speakwrite-instrumented editor. The keystroke dynamics are genuine because the typing is genuine; only the intellectual origin is artificial. |
| **Difficulty** | Low (for the adversary) |
| **Mitigation** | This is the protocol's most fundamental limitation. Partial mitigations include: (a) detecting transcription-consistent behavioral patterns — transcription from a visible source typically exhibits more regular pacing, fewer substantive revisions, and shorter cognitive pauses compared to original composition; (b) analyzing the ratio of "thinking time" to "typing time" — original composition involves extended pauses for ideation that transcription typically does not; (c) detecting unusually low error rates for the observed typing speed — transcribing visible text produces fewer errors than composing novel text; (d) cross-referencing the document against known AI text patterns (though this returns us to the output-analysis arms race the protocol seeks to avoid). |
| **Residual Risk** | **High.** A careful transcriber who intentionally varies their pacing, introduces and corrects deliberate errors, and pauses to simulate thinking may be indistinguishable from an original composer. The protocol is honest about this limitation. |

#### 3.4.8 Post-Signing Document Modification

| Property | Value |
|---|---|
| **Adversary Class** | II |
| **Description** | After a legitimate attestation is produced, the adversary modifies the document while hoping the Verifier does not check the document hash. |
| **Difficulty** | Infeasible (against compliant Verifier), Trivial (against negligent Verifier) |
| **Mitigation** | The attestation includes $H_d = H(D)$ and the Verifier's first step is recomputing and comparing this hash. Any modification to the document, including a single bit flip, results in a hash mismatch and attestation failure. |
| **Residual Risk** | Negligible, assuming the Verifier performs hash verification. The protocol cannot prevent a Verifier from ignoring the hash check, but such a Verifier is non-compliant. |

#### 3.4.9 Sybil Attacks

| Property | Value |
|---|---|
| **Adversary Class** | II or III |
| **Description** | The adversary creates multiple pseudonymous Speakwrite identities, each backed by a separate (fraudulently obtained) World ID credential, to accumulate independent trust histories. |
| **Difficulty** | High (requires defeating World ID biometric enrollment for each additional identity) |
| **Mitigation** | The protocol's Sybil resistance is directly inherited from the World ID protocol. The cost of creating an additional identity is the cost of fraudulently obtaining an additional World ID credential, which requires either biometric spoofing at enrollment or physical coercion of another human. This cost is designed to be high and to scale linearly with the number of additional identities. |
| **Residual Risk** | Low, assuming World ID enrollment integrity. The protocol's Sybil resistance is exactly as strong as World ID's Sybil resistance — no more, no less. |

#### 3.4.10 Side-Channel Attacks on the Observer

| Property | Value |
|---|---|
| **Adversary Class** | I or II |
| **Description** | An adversary with access to the Author's device (via malware, physical access, or a compromised application running concurrently) extracts raw keystroke timing data from the Observer's memory, or infers behavioral characteristics from observable side channels (power consumption, electromagnetic emissions, acoustic emanations of keystrokes). |
| **Difficulty** | Moderate to High |
| **Mitigation** | (a) The Observer should minimize the time window during which raw timing data exists in memory, computing the BFV incrementally and discarding raw events. (b) The Observer should use memory protection mechanisms provided by the operating system. (c) Acoustic and electromagnetic side channels are out of scope for the base protocol but are noted as areas for future hardening. (d) The protocol's privacy properties ensure that even if the BFV is extracted, it reveals only aggregate statistical features, not raw biometric data. |
| **Residual Risk** | Moderate. Side-channel attacks are a general concern for any client-side software and are not unique to this protocol. The protocol's primary defense is that the BFV is less sensitive than raw timing data, limiting the value of side-channel extraction. |

#### 3.4.11 Collusion Attacks

| Property | Value |
|---|---|
| **Adversary Class** | III or IV |
| **Description** | Multiple parties collude to defeat the protocol. Examples: (a) a person with a World ID credential provides their signing key to a skilled typist who transcribes AI-generated content; (b) a group pools resources to build a sophisticated keystroke simulator and shares it; (c) an organization systematically employs human transcribers to produce attested AI-generated content at scale. |
| **Difficulty** | Moderate to High (coordination cost) |
| **Mitigation** | (a) Progressive trust analysis detects behavioral inconsistencies when multiple humans share a credential. (b) Scaling transcription-based attacks requires proportional human labor, which limits throughput and increases cost — this is a feature, not a bug, as it restores the economic constraints that AI generation circumvents. (c) The protocol cannot prevent collusion, but it ensures that colluding parties must invest resources proportional to the volume of forged content. |
| **Residual Risk** | Moderate. Collusion is a fundamental limitation of any cryptographic protocol where participants have economic incentives to cheat. The protocol's contribution is making solo forgery expensive and collusion-based forgery scale linearly with human labor. |

### 3.5 Security Properties

The following formal properties are claimed by the protocol, subject to the trust assumptions in Section 3.2.

#### 3.5.1 Integrity

**Property.** Given a valid attestation $A$ for document $D$, any modification to $D$ producing $D' \neq D$ is detectable by the Verifier.

**Formally.** For all probabilistic polynomial-time adversaries $\mathcal{E}$:

$$\Pr[\mathcal{V}.\text{Verify}(D', A) = \text{accept} \mid D' \neq D \land \mathcal{V}.\text{Verify}(D, A) = \text{accept}] \leq \text{negl}(\lambda)$$

where $\lambda$ is the security parameter and $\text{negl}$ denotes a negligible function.

**Basis.** Follows from the collision resistance of $H$ and the unforgeability of the signature scheme.

#### 3.5.2 Binding

**Property.** A valid attestation binds together the document, the behavioral evidence, the personhood proof, and the author's identity. No component can be substituted without invalidating the attestation.

**Formally.** For all PPT adversaries $\mathcal{E}$, the probability of producing $(D, A)$ and $(D, A')$ such that $A \neq A'$ and both verify successfully under the same public key $pk$ with the same document hash is negligible. Equivalently, the adversary cannot produce an attestation $A^*$ that verifies for document $D$ with a BFV or CTH different from the ones committed to in the original signing.

**Basis.** Follows from the EUF-CMA security of the signature scheme. The signature covers the entire attestation structure; any modification to any field invalidates the signature.

#### 3.5.3 Non-Repudiation

**Property.** An Author who has produced a valid attestation cannot later deny having produced it, assuming their signing key was not compromised.

**Formally.** If $\mathcal{V}.\text{Verify}(D, A) = \text{accept}$ and $A$ contains a valid signature under $pk$, then the holder of the corresponding $sk$ produced $A$ (or $sk$ was compromised).

**Basis.** Follows from the unforgeability of the signature scheme. This property is standard for digital signature-based attestations.

**Limitation.** Non-repudiation applies to the *production of the attestation*, not to the *composition of the document*. An Author can claim their key was compromised, or that the Observer was modified by malware, or that someone else used their device. The protocol provides evidence against such claims (via behavioral consistency with the Author's established profile) but cannot mathematically refute them.

#### 3.5.4 Sybil Resistance

**Property.** A single human can control at most one Speakwrite pseudonymous identity.

**Formally.** For any human $h$ who has enrolled in World ID exactly once, the probability that $h$ can produce valid attestations under two distinct pseudonymous identities $pk_1 \neq pk_2$, each with valid personhood proofs, is negligible.

**Basis.** Follows from the Sybil resistance of the World ID protocol. The Speakwrite identity derivation ensures a deterministic mapping from World ID credential to Speakwrite signing key, preventing a single World ID credential from generating multiple independent signing keys.

**Degradation.** This property is exactly as strong as World ID's biometric enrollment. If World ID is compromised (e.g., biometric spoofing at scale), Sybil resistance degrades proportionally.

#### 3.5.5 Privacy Preservation

**Property.** A published attestation reveals no information about the Author beyond: (a) the document itself, (b) the statistical behavioral features intentionally included in the BFV, (c) the fact that the Author is a unique human, and (d) the pseudonymous identity $pk$. In particular, the attestation does not reveal: the Author's real-world identity, the Author's World ID enrollment data, the raw keystroke timing sequence, or any biometric data sufficient for impersonation.

**Formally.** The zero-knowledge property of $\pi_{wid}$ ensures that the personhood proof reveals nothing beyond the statement "the holder of $pk$ is a unique human enrolled in World ID." The BFV is a lossy transformation of raw keystroke data — it preserves aggregate statistics while discarding individual event timings. The CTH is a one-way hash that commits to the editing sequence without revealing it.

**Limitation.** The BFV, while not containing raw timing data, does contain behavioral statistics that may constitute a behavioral biometric fingerprint. Over a large corpus of attestations, a BFV profile may be sufficiently distinctive to link a pseudonymous identity across contexts. This is a privacy-utility tradeoff: richer behavioral features provide stronger forgery resistance but weaker behavioral anonymity. The protocol's design allows configurable BFV granularity to let authors choose their position on this tradeoff.

#### 3.5.6 Forgery Cost Escalation

**Property.** The cost of producing a convincing forged attestation for an AI-generated document is substantially greater than the cost of generating the document itself, and this cost increases with the sophistication of the Verifier's analysis.

**Informally.** Generating a document with a language model costs approximately $c_{gen}$ (a single API call). Producing a convincing forged attestation requires, at minimum, either: (a) building or obtaining a sophisticated keystroke dynamics simulator and running it for each document (cost $c_{sim} \gg c_{gen}$), or (b) employing a human to transcribe the document (cost $c_{human} \gg c_{gen}$, and scaling linearly with document volume). The protocol does not eliminate the possibility of forgery but ensures that forgery restores a significant cost to AI-generated content production.

**This is not a formal cryptographic property.** It is an economic argument about the cost structure the protocol imposes. The protocol's value proposition rests on maintaining a significant gap between $c_{gen}$ and $\min(c_{sim}, c_{human})$.

### 3.6 Honest Limitations

The following limitations are inherent to the protocol's approach and cannot be eliminated through engineering improvements within the current architectural framework. They are stated here for intellectual honesty and to set appropriate expectations for implementers and relying parties.

**L-1: The Transcription Boundary.** Any protocol that verifies *process* rather than *intent* is fundamentally unable to distinguish original composition from transcription of externally generated content. A human physically typing AI-generated text produces genuine human keystroke dynamics. This is an irreducible limitation of the process-verification approach. Mitigations exist (Section 3.4.7) but cannot provide guarantees.

**L-2: Observer Trust.** The Observer is a client-side component running on the Author's device. The protocol cannot enforce that the Observer has not been modified, bypassed, or replaced with a fabricating alternative. Hardware-backed attestation can raise the bar but cannot eliminate this concern, as hardware attestation itself has known limitations and attacks. The Observer is, and will remain, the weakest link in the trust chain.

**L-3: Behavioral Feature Arms Race.** While the current asymmetry favors the protocol (capturing real behavior is easy; simulating it across many dimensions is hard), this asymmetry may narrow over time as generative models of human motor behavior improve. The protocol's extensible feature set provides a defense-in-depth strategy, but there is no proof that the defender will maintain an advantage indefinitely. The protocol may eventually become a speed bump rather than a barrier against sufficiently advanced simulation.

**L-4: World ID Dependency.** The protocol's Sybil resistance is entirely dependent on the World ID system. Any compromise of World ID's biometric enrollment — whether through technical attacks, social engineering, or changes in the World ID governance model — directly compromises Speakwrite's Sybil resistance. The protocol has no independent mechanism for enforcing one-identity-per-person.

**L-5: Probabilistic, Not Deterministic.** The protocol produces a confidence score, not a binary determination. There will always be false positives (genuine human writing that scores low due to atypical typing behavior, use of assistive technology, or composition methods that differ from the training distribution) and false negatives (forged attestations that score high due to sophisticated simulation). Relying parties must understand that Speakwrite attestations are forensic evidence subject to interpretation, not mathematical proof.

**L-6: Accessibility and Inclusivity.** The protocol's reliance on keystroke dynamics as the primary behavioral signal creates inherent challenges for users who do not use standard keyboard input: users of assistive technology, users who compose via dictation, users with motor impairments that alter keystroke dynamics, and users of non-Latin input methods that involve composition (e.g., CJK input method editors). Future versions of the specification must address these accessibility concerns, potentially through alternative behavioral observation modalities. Until then, the protocol's applicability is limited to authors who compose via conventional keyboard input.

**L-7: No Retroactive Verification.** Documents composed without an active Observer cannot be retroactively attested. The protocol provides no mechanism for proving human authorship of content that was not instrumented at the time of composition. This limits adoption in contexts where existing content needs authentication.

---

*Sections 4 through 9 (Behavioral Observation, Cryptographic Construction, Attestation Format, Verification Procedure, Progressive Trust Model, and Implementation Guidance) are forthcoming in subsequent revisions of this specification.*

## 4. Behavioral Capture System

The Behavioral Capture System is the sensory layer of the Speakwrite protocol. It is responsible for faithfully recording the raw observable events produced during a human writing session, managing the lifecycle of sensitive data, and maintaining session integrity across interruptions. All downstream analysis, feature extraction, and cryptographic commitment depend on the fidelity and completeness of this layer.

### 4.1 Observable Events

#### 4.1.1 Event Model Overview

The capture system records a totally ordered event stream `E = (e_1, e_2, ..., e_n)` where each event `e_i` is a tuple `(type, fields, t_i)` with `t_i` being a high-resolution timestamp. Events are captured from the browser's DOM event model and normalized into the protocol's internal representation.

**Timestamp Requirements:**

- All timestamps MUST be obtained from `performance.now()` (or equivalent monotonic high-resolution clock), NOT from `Date.now()`.
- Timestamps MUST have microsecond precision (i.e., at minimum three decimal places on a millisecond-resolution clock: `performance.now()` returns `DOMHighResTimeStamp` with sub-millisecond precision).
- Timestamps MUST be monotonically non-decreasing within a session.
- The absolute epoch offset `T_0` MUST be recorded once at session initialization as `T_0 = Date.now()` paired with `performance.now()` to allow later correlation to wall-clock time if needed. All subsequent event timestamps are relative to the `performance.now()` baseline.
- Timestamp resolution MUST be at least 1 millisecond. Implementations SHOULD target 0.1 ms where the platform permits. Implementations MUST document their effective resolution.

**Event Ordering Guarantees:**

- Events MUST be recorded in the order they are dispatched by the user agent's event loop.
- When multiple events share the same timestamp (within platform resolution), their order MUST be preserved as dispatched.
- The capture layer MUST assign a strictly monotonically increasing sequence number `seq_i` (uint64) to each event, independent of timestamps, to resolve any ordering ambiguity: `seq_i < seq_j => i < j`.
- If the platform coalesces rapid events (e.g., `mousemove`), the implementation MUST document which event types are subject to coalescing and at what rate.

**Rapid Event Handling:**

- The capture layer MUST NOT drop events under high-frequency input (e.g., key repeat, rapid mouse movement).
- If the implementation uses a ring buffer or bounded queue, the buffer size MUST be at least 10,000 events. If the buffer is exhausted, the session MUST be marked as `degraded` (see Section 4.3) and the gap recorded.
- Events arriving faster than the platform's timer resolution MUST still be recorded with their dispatch-order sequence numbers; implementations MUST NOT synthesize artificial timestamp separation.

**Deduplication Rules:**

- `keydown` events with `repeat = true` MUST be captured but MUST be flagged as `repeat` in the event record. Feature extraction (Section 5) defines how repeats are handled per-feature.
- Duplicate `selectionchange` events (identical `anchorOffset`, `focusOffset`, `anchorNode`, `focusNode` to the immediately preceding `selectionchange`) MUST be suppressed.
- All other event types MUST NOT be deduplicated; apparent duplicates may carry distinct semantic meaning.

#### 4.1.2 KeyboardEvent

Captured on: `keydown`, `keyup`

| Field | Type | Description |
|-------|------|-------------|
| `event_subtype` | enum {`keydown`, `keyup`} | Which phase of the key lifecycle |
| `key` | string | The `KeyboardEvent.key` value (logical key, e.g., `"a"`, `"Shift"`, `"ArrowLeft"`) |
| `code` | string | The `KeyboardEvent.code` value (physical key, e.g., `"KeyA"`, `"ShiftLeft"`) |
| `timestamp` | float64 | High-resolution timestamp (ms, relative to session epoch) |
| `seq` | uint64 | Monotonic sequence number |
| `shift` | bool | `true` if Shift modifier active |
| `ctrl` | bool | `true` if Control modifier active |
| `alt` | bool | `true` if Alt/Option modifier active |
| `meta` | bool | `true` if Meta/Command modifier active |
| `repeat` | bool | `true` if this is a key-repeat event (key held down) |
| `isComposing` | bool | `true` if this event is part of an IME composition sequence |
| `location` | uint8 | `KeyboardEvent.location` (0 = standard, 1 = left, 2 = right, 3 = numpad) |

**Normalization:**

- The `key` field MUST be recorded as-is from the browser. Implementations MUST NOT normalize case (the presence or absence of Shift is recorded separately).
- The `code` field represents the physical key position and is locale-independent. It MUST always be present; if the platform does not provide it, the field MUST be set to `"Unidentified"` and the event flagged.
- Dead keys (e.g., accent keys in European layouts) MUST be captured. The `key` value will be `"Dead"` until the composition resolves.

**Privacy Note:** The `key` field contains the actual character typed. It is classified as **ephemeral data** (see Section 4.2). It MUST NOT be persisted beyond the active session's in-memory processing.

#### 4.1.3 InputEvent

Captured on: `input`, `beforeinput`

| Field | Type | Description |
|-------|------|-------------|
| `event_subtype` | enum {`beforeinput`, `input`} | Event phase |
| `inputType` | string | The `InputEvent.inputType` value (see enumeration below) |
| `data` | string or null | The `InputEvent.data` value (inserted text, if any) |
| `data_length` | uint32 | Length of `data` in UTF-16 code units (0 if null) |
| `timestamp` | float64 | High-resolution timestamp |
| `seq` | uint64 | Monotonic sequence number |
| `isComposing` | bool | `true` if part of an IME composition |

**Enumerated `inputType` values that MUST be captured:**

The following is the complete set of `inputType` values relevant to Speakwrite. Implementations MUST capture all of these and MUST record any unlisted `inputType` values verbatim (for forward-compatibility).

*Insertion types:*
- `insertText` -- character(s) inserted via keyboard
- `insertReplacementText` -- text replaced by autocorrect/spellcheck
- `insertLineBreak` -- soft line break (Shift+Enter)
- `insertParagraph` -- hard paragraph break (Enter)
- `insertOrderedList` -- insertion from ordered list creation
- `insertUnorderedList` -- insertion from unordered list creation
- `insertHorizontalRule` -- horizontal rule insertion
- `insertFromYank` -- paste from kill ring (macOS)
- `insertFromDrop` -- text dropped via drag-and-drop
- `insertFromPaste` -- text pasted from clipboard
- `insertFromPasteAsQuotation` -- paste as block quote
- `insertTranspose` -- character transposition (Ctrl+T on macOS)
- `insertCompositionText` -- IME composition intermediate text
- `insertLink` -- hyperlink insertion

*Deletion types:*
- `deleteWordBackward` -- delete word before cursor
- `deleteWordForward` -- delete word after cursor
- `deleteSoftLineBackward` -- delete to beginning of soft line
- `deleteSoftLineForward` -- delete to end of soft line
- `deleteHardLineBackward` -- delete to beginning of hard line
- `deleteHardLineForward` -- delete to end of hard line
- `deleteEntireSoftLine` -- delete entire soft line
- `deleteContent` -- generic content deletion
- `deleteContentBackward` -- delete one unit backward (Backspace)
- `deleteContentForward` -- delete one unit forward (Delete)
- `deleteByCut` -- delete by cut operation
- `deleteByDrag` -- delete by drag operation

*History types:*
- `historyUndo` -- undo operation
- `historyRedo` -- redo operation

*Formatting types (captured but not primary behavioral signals):*
- `formatBold`, `formatItalic`, `formatUnderline`, `formatStrikeThrough`
- `formatSuperscript`, `formatSubscript`
- `formatJustifyFull`, `formatJustifyCenter`, `formatJustifyRight`, `formatJustifyLeft`
- `formatIndent`, `formatOutdent`
- `formatSetBlockTextDirection`, `formatSetInlineTextDirection`
- `formatBackColor`, `formatFontColor`, `formatFontName`
- `formatRemove`

**Privacy Note:** The `data` field contains inserted text content. It is classified as **ephemeral data** (see Section 4.2).

#### 4.1.4 SelectionChangeEvent

Captured on: `selectionchange` (document-level)

| Field | Type | Description |
|-------|------|-------------|
| `anchorNode_id` | string | Stable identifier of the anchor node in the DOM (see below) |
| `anchorOffset` | uint32 | Character offset within anchor node |
| `focusNode_id` | string | Stable identifier of the focus node |
| `focusOffset` | uint32 | Character offset within focus node |
| `isCollapsed` | bool | `true` if the selection is a caret (zero-width) |
| `direction` | enum {`forward`, `backward`, `none`} | Direction of selection |
| `timestamp` | float64 | High-resolution timestamp |
| `seq` | uint64 | Monotonic sequence number |

**Node Identification:**

The implementation MUST assign stable opaque identifiers to DOM nodes within the editable region. These identifiers MUST NOT expose DOM structure or content. A suitable scheme is to assign monotonically increasing integer IDs to nodes as they are first referenced, stored in a `WeakMap<Node, uint32>`. Node identifiers are **ephemeral** and are not persisted.

#### 4.1.5 MouseEvent

Captured on: `mousedown`, `mouseup`, `click`, `mousemove` (throttled)

| Field | Type | Description |
|-------|------|-------------|
| `event_subtype` | enum {`mousedown`, `mouseup`, `click`, `mousemove`} | Mouse event type |
| `x` | float64 | Viewport-relative X coordinate (pixels) |
| `y` | float64 | Viewport-relative Y coordinate (pixels) |
| `button` | uint8 | Mouse button (0 = primary, 1 = middle, 2 = secondary) |
| `timestamp` | float64 | High-resolution timestamp |
| `seq` | uint64 | Monotonic sequence number |

**Throttling:** `mousemove` events MUST be captured at no more than 60 Hz (approximately one event per 16.67 ms). The implementation SHOULD use `requestAnimationFrame`-aligned sampling or an equivalent mechanism. When throttling, the most recent event in each frame interval MUST be retained. All other mouse event subtypes MUST NOT be throttled.

**Privacy Note:** Absolute coordinates (x, y) are classified as **ephemeral**. Only relative motion vectors and aggregate statistics are persisted.

#### 4.1.6 WheelEvent

Captured on: `wheel`

| Field | Type | Description |
|-------|------|-------------|
| `deltaX` | float64 | Horizontal scroll delta (pixels, with `deltaMode` normalization) |
| `deltaY` | float64 | Vertical scroll delta (pixels) |
| `deltaMode` | uint8 | Original delta mode (0 = pixel, 1 = line, 2 = page) |
| `timestamp` | float64 | High-resolution timestamp |
| `seq` | uint64 | Monotonic sequence number |

**Normalization:** Implementations MUST normalize `deltaX` and `deltaY` to pixel units regardless of the original `deltaMode`. Line-mode deltas MUST be multiplied by the current computed line height; page-mode deltas by the viewport height. The original `deltaMode` MUST be preserved for verification.

#### 4.1.7 FocusEvent

Captured on: `focus`, `blur` (on the editable element or window)

| Field | Type | Description |
|-------|------|-------------|
| `event_subtype` | enum {`focus`, `blur`} | Focus event type |
| `target_type` | enum {`editor`, `window`, `other`} | What gained or lost focus |
| `timestamp` | float64 | High-resolution timestamp |
| `seq` | uint64 | Monotonic sequence number |

#### 4.1.8 ClipboardEvent

Captured on: `paste`, `copy`, `cut`

| Field | Type | Description |
|-------|------|-------------|
| `event_subtype` | enum {`paste`, `copy`, `cut`} | Clipboard operation type |
| `data_length` | uint32 | Length of clipboard text content in UTF-16 code units |
| `mime_types` | string[] | List of MIME types present in the `DataTransfer` object |
| `timestamp` | float64 | High-resolution timestamp |
| `seq` | uint64 | Monotonic sequence number |

**Privacy Constraint:** The actual clipboard content MUST NOT be recorded. Only the length (`data_length`) and the list of available MIME types are captured. This is a hard requirement; no implementation mode or configuration flag may override it.

#### 4.1.9 CompositionEvent

Captured on: `compositionstart`, `compositionupdate`, `compositionend`

| Field | Type | Description |
|-------|------|-------------|
| `event_subtype` | enum {`compositionstart`, `compositionupdate`, `compositionend`} | Composition lifecycle phase |
| `data` | string | The current composition string |
| `data_length` | uint32 | Length of composition string in UTF-16 code units |
| `timestamp` | float64 | High-resolution timestamp |
| `seq` | uint64 | Monotonic sequence number |

**IME Considerations:**

- Composition events are critical for supporting CJK (Chinese, Japanese, Korean) input methods, Indic language input, and other complex input methods.
- During an active composition (`compositionstart` to `compositionend`), `KeyboardEvent` events with `isComposing = true` MUST still be captured, but they MUST be marked as composition-internal and excluded from standard temporal feature computation (see Section 5.1.1).
- The number of `compositionupdate` events and their timing constitute a behavioral signal (different IME usage patterns) and MUST be captured.
- The `data` field is **ephemeral**.

#### 4.1.10 Internal Synthetic Events

In addition to browser DOM events, the capture system MUST generate the following synthetic events:

| Synthetic Event | Trigger | Fields |
|----------------|---------|--------|
| `session_start` | Session initialization | `session_id`, `timestamp`, `document_id`, `user_agent_hash` |
| `session_end` | Session termination | `session_id`, `timestamp`, `reason` (enum: `explicit`, `timeout`, `abandonment`, `error`) |
| `session_pause` | Editor blur / idle threshold exceeded | `timestamp`, `reason` |
| `session_resume` | Editor focus after pause | `timestamp`, `pause_duration_ms` |
| `capture_degraded` | Event buffer overflow or other capture failure | `timestamp`, `reason`, `events_lost_estimate` |
| `window_resize` | Viewport dimensions change | `timestamp`, `width`, `height` |

### 4.2 Privacy-Sensitive Data Handling

#### 4.2.1 Data Zone Classification

All data within the Speakwrite system is classified into exactly one of two zones:

**Ephemeral Zone** -- Data that exists only in volatile memory during the active writing session. It MUST NOT be written to disk, transmitted over a network, or persisted in any form beyond the boundaries defined below.

**Persistent Zone** -- Data that is committed to the behavioral proof and may be stored, transmitted, and cryptographically signed. All persistent data consists exclusively of statistical aggregates, distributions, hashes, and metadata. It MUST NOT contain any information from which original text content can be reconstructed.

#### 4.2.2 Ephemeral Data Inventory

The following data elements are classified as **ephemeral**:

| Data Element | Source | Purpose | Destruction Trigger |
|-------------|--------|---------|-------------------|
| `KeyboardEvent.key` values | Section 4.1.2 | Digraph/trigraph timing computation | After feature extraction for containing window |
| `InputEvent.data` values | Section 4.1.3 | Content arrival mode classification | After feature extraction for containing window |
| `CompositionEvent.data` values | Section 4.1.9 | IME pattern analysis | After composition sequence ends |
| `SelectionChangeEvent` node IDs | Section 4.1.4 | Cursor position tracking | After feature extraction for containing window |
| `MouseEvent` absolute coordinates | Section 4.1.5 | Navigation pattern analysis | After conversion to relative vectors |
| Raw event stream `E` | Section 4.1.1 | All feature extraction | After window commitment |
| Character-to-key mappings | Runtime | Digraph matrix construction | After matrix computation |
| Clipboard text content | Never captured | N/A | N/A (never enters system) |

#### 4.2.3 Data Lifecycle

The lifecycle of behavioral data proceeds through exactly five stages:

```
Stage 1: CAPTURE
  Raw events are pushed into an in-memory ring buffer.
  Duration: Real-time (events exist here for at most one extraction window period).
  Storage: Volatile memory only.
  Contains: Full event records including ephemeral fields.

Stage 2: EXTRACTION
  Feature extraction (Section 5) processes raw events within a time window.
  Duration: Milliseconds to seconds (computation time).
  Storage: Volatile memory only.
  Contains: Intermediate computation state (e.g., partial digraph counts).

Stage 3: AGGREGATION
  Window-level features are computed and the raw events for that window
  are eligible for destruction.
  Duration: Instantaneous (output of extraction).
  Storage: Volatile memory. May be promoted to persistent storage.
  Contains: Feature vectors (all ephemeral data has been aggregated away).

Stage 4: COMMITMENT
  Aggregated features are cryptographically committed (see Section [future]).
  Duration: Instantaneous.
  Storage: Persistent (signed commitment).
  Contains: Feature vector hash, Merkle inclusion proof, timestamp.

Stage 5: DESTRUCTION
  Ephemeral data from Stages 1-2 is destroyed.
  Duration: Immediate after Stage 3 completion for a given window.
  Storage: N/A.
  Contains: N/A.
```

#### 4.2.4 Destruction Requirements

- **Timing:** Ephemeral data for a given extraction window MUST be destroyed within 60 seconds of the completion of feature extraction for that window. Implementations SHOULD destroy it immediately.
- **Method:** Destruction MUST consist of zeroing the memory region and releasing it. In garbage-collected environments (JavaScript), destruction consists of removing all references to the data and, where available, explicitly overwriting `ArrayBuffer` contents with zeros via `TypedArray.fill(0)` before dereferencing.
- **Verification:** Implementations MUST maintain a destruction log (itself ephemeral, destroyed at session end) recording the timestamp and byte count of each destruction operation. This log is available for audit during the session but is not persisted.
- **Failure Mode:** If destruction cannot be confirmed (e.g., the page is terminated abruptly), the next session initialization MUST NOT attempt to recover any prior ephemeral data. Any data found in an unclean state MUST be discarded without processing.

#### 4.2.5 Persistent Data Constraints

Data in the Persistent Zone MUST satisfy the following properties:

1. **Non-invertibility:** It MUST be computationally infeasible to reconstruct the original text content from the persistent data. Formally: given the persistent feature vector `F` and all public protocol parameters, no polynomial-time algorithm should recover more than a negligible fraction of the original character sequence.

2. **Statistical nature:** All persistent values MUST be one of:
   - Counts (e.g., total keystrokes, deletion count)
   - Statistical moments (mean, variance, skewness, kurtosis of timing distributions)
   - Histogram bin counts with bin edges defined by the protocol (not by the data)
   - Cryptographic hashes (SHA-256 or equivalent)
   - Boolean flags
   - Enumerated categorical values

3. **No sequence data:** The persistent zone MUST NOT contain any ordered sequence of individual event timestamps, individual event types, or any data structure from which the temporal order of specific characters can be inferred. Timing data is retained only as distributions over defined categories (digraph classes, pause categories, etc.).

4. **Minimum aggregation threshold:** No persistent statistical value may be computed from fewer than `k_min = 5` observations. If a category (e.g., a rare digraph) has fewer than `k_min` observations in a window, it MUST be reported as `null` / absent rather than as a potentially identifying precise value.

### 4.3 Session Management

#### 4.3.1 Session Initialization

A session begins when the user activates the Speakwrite capture in a writing environment. The initialization procedure is:

```
PROCEDURE InitializeSession(document_id):
  1. Generate session_id := UUID v4 (cryptographically random)
  2. Record T_0_wall := Date.now()            // Wall-clock epoch (ms since Unix epoch)
  3. Record T_0_mono := performance.now()      // Monotonic epoch (ms, arbitrary origin)
  4. Initialize event ring buffer B with capacity 10,000 events
  5. Initialize sequence counter seq := 0
  6. Initialize session state := ACTIVE
  7. Initialize window state:
       window_start := T_0_mono
       window_index := 0
  8. Record environment metadata (persistent):
       - user_agent_hash := SHA-256(navigator.userAgent)  // not the raw string
       - viewport_width, viewport_height
       - timezone_offset := new Date().getTimezoneOffset()
       - platform_timestamp_resolution := measured resolution (see below)
  9. If document_id references a prior session's commitment chain:
       Load prior session's terminal feature summary for continuity
  10. Emit synthetic event session_start
  11. Begin event listeners on the editable region
```

**Timestamp Resolution Measurement:**

At initialization, the implementation MUST measure the effective timestamp resolution by sampling `performance.now()` in a tight loop and recording the minimum observed nonzero difference across at least 100 consecutive calls. This value (`platform_timestamp_resolution`) is stored as session metadata and used to set minimum bin widths in timing histograms.

#### 4.3.2 Session Continuity

**Focus/Blur Handling:**

- When the editable region or browser window loses focus (`blur` event), the session transitions to `PAUSED` state.
- A `session_pause` synthetic event is emitted with the timestamp.
- During `PAUSED` state, no behavioral events are captured (there are none to capture, since the editor is not focused).
- When focus returns, a `session_resume` synthetic event is emitted.
- The pause duration is recorded and used in Session Macro-Structure features (Section 5.1.6).
- Events that occur between blur and focus (e.g., keyboard events dispatched to other elements) are NOT captured and this gap is explicitly modeled.

**Idle Detection:**

- If no event is received for `T_idle = 120 seconds` (2 minutes) while the session is `ACTIVE`, the session transitions to `IDLE`.
- An `IDLE` session behaves identically to `PAUSED` for data purposes.
- The distinction is semantic: `PAUSED` indicates the user shifted attention elsewhere; `IDLE` indicates the user may still be looking at the editor but not interacting.
- If no event is received for `T_abandon = 3600 seconds` (1 hour) from the last event, the session transitions to `ABANDONED` and terminates (see Section 4.3.3).

**Visibility API Integration:**

- The implementation SHOULD listen for the `visibilitychange` event on the `document` object.
- When `document.visibilityState` transitions to `"hidden"`, this is treated equivalently to a `blur` event for session state purposes.
- This handles cases where the user switches tabs without the editor explicitly losing focus.

#### 4.3.3 Session Termination

A session terminates under exactly one of the following conditions:

| Condition | Trigger | `reason` value |
|-----------|---------|----------------|
| **Explicit end** | User clicks "stop recording" or equivalent UI action | `explicit` |
| **Timeout** | `T_abandon` exceeded with no events | `abandonment` |
| **Page unload** | `beforeunload` / `pagehide` event | `explicit` (if orderly) or `abandonment` (if abrupt) |
| **Error** | Unrecoverable capture error (e.g., event listener detached) | `error` |
| **Maximum duration** | Session wall-clock duration exceeds `T_max_session = 14400 seconds` (4 hours) | `explicit` |

**Termination Procedure:**

```
PROCEDURE TerminateSession(reason):
  1. Set session state := TERMINATED
  2. Remove all event listeners
  3. Process any remaining events in buffer B through feature extraction
  4. Compute final window features (even if window is incomplete;
     mark as partial if keystroke count < W_min)
  5. Compute session-level aggregate features from all window features
  6. Emit synthetic event session_end with reason
  7. Produce session commitment:
       session_summary := {
         session_id,
         document_id,
         T_0_wall,
         duration_ms,
         total_events,
         total_keystrokes,
         session_state_log,       // sequence of (state, timestamp) transitions
         window_commitments[],    // array of per-window cryptographic commitments
         session_feature_vector,  // aggregated feature vector (Section 5.2)
         reason
       }
  8. Destroy all ephemeral data (Section 4.2.4)
  9. Return session_summary for cryptographic signing (Section [future])
```

**Graceful Degradation on Abrupt Termination:**

If the page is killed without a `beforeunload` event (e.g., browser crash, force-quit), the session data in memory is lost. The protocol handles this as follows:

- Any windows that were previously committed remain valid.
- The incomplete final window is lost. This is acceptable; the proof covers only committed windows.
- On the next session initialization, if the same `document_id` is provided, the system detects the gap and records it as a `session_gap` in the document's behavioral history.

#### 4.3.4 Multi-Session Documents

A single document may be authored across multiple sessions. The protocol maintains continuity through the **document behavioral chain**:

```
Document D has sessions S_1, S_2, ..., S_m

Each session S_j produces:
  - A session feature vector F_j
  - A chain link: L_j = {
      session_id_j,
      document_id,
      prev_link_hash: SHA-256(L_{j-1})  (or null for j=1),
      session_feature_hash: SHA-256(F_j),
      start_time: T_0_wall for S_j,
      end_time: termination wall-clock time for S_j,
      total_keystrokes_cumulative: sum of keystrokes through S_j
    }
```

**Merging Rules:**

- Session-level feature vectors are NOT naively averaged. Instead, the document-level feature vector is computed by weighted combination, where the weight of session `S_j` is proportional to the number of valid (non-partial) windows in that session:

  `F_document = SUM_j (w_j * F_j) / SUM_j (w_j)` where `w_j = |valid_windows(S_j)|`

- Distributions (histograms, digraph matrices) are merged by summing bin counts across sessions before recomputing statistics.
- The document behavioral chain provides an auditable record that the document was authored incrementally.

#### 4.3.5 Maximum Session Duration

- `T_max_session = 14400 seconds` (4 hours).
- When this limit is reached, the session terminates with `reason = explicit` and the user is prompted to start a new session if they wish to continue.
- Rationale: Sessions beyond 4 hours are likely to exhibit significant fatigue effects that alter the behavioral baseline. Splitting into separate sessions allows fatigue to be modeled per-session rather than requiring intra-session normalization over extreme durations.
- The multi-session document mechanism (Section 4.3.4) ensures no data is lost.

---

## 5. Feature Extraction

Feature extraction transforms the raw event stream captured in Section 4 into a structured, privacy-preserving feature vector that characterizes the behavioral signature of the writing session. The features are organized into six tiers of increasing abstraction, from sub-second motor timing to session-scale compositional patterns.

### 5.1 Feature Taxonomy

#### 5.1.1 Tier 1: Temporal Microstructure

Temporal microstructure features capture the fine-grained timing patterns of keystroke production. These are the most discriminative features for individual identification and the most difficult to simulate.

**Definitions:**

Let `K = (k_1, k_2, ..., k_n)` be the sequence of non-modifier, non-repeat `keydown` events in a window, ordered by sequence number. Let `t_d(k_i)` denote the `keydown` timestamp of key event `k_i` and `t_u(k_i)` denote the corresponding `keyup` timestamp. Let `c(k_i)` denote the character produced by key event `k_i` (derived from the `key` field; for non-character keys, a canonical label is used, e.g., `"BACKSPACE"`, `"ENTER"`).

**Flight Time (Inter-Key Interval):**

```
F(k_i, k_{i+1}) = t_d(k_{i+1}) - t_d(k_i)
```

- Unit: milliseconds (float64)
- Domain: `[0, +inf)`. Values exceeding `T_pause_max = 30000 ms` are classified as breaks and excluded from flight time distributions (they are captured instead in pause analysis, Section 5.1.3).
- Flight times for key pairs separated by a `session_pause` or `session_resume` synthetic event MUST be excluded.
- Flight times involving `keydown` events with `isComposing = true` MUST be excluded from standard flight time computation and instead routed to a separate IME timing analysis.

**Hold Time (Key Duration / Dwell Time):**

```
H(k_i) = t_u(k_i) - t_d(k_i)
```

- Unit: milliseconds (float64)
- Domain: `[0, T_hold_max]` where `T_hold_max = 1000 ms`. Values exceeding `T_hold_max` are capped and flagged (likely the key was held for repeat or the `keyup` was missed).
- If no matching `keyup` is observed for a `keydown` (e.g., focus lost while key was pressed), the hold time is recorded as `null`.

**Digraph Latency Matrix:**

For each ordered pair of characters `(c1, c2)` observed in adjacent keystrokes:

```
D[c1][c2] = { F(k_i, k_{i+1}) : c(k_i) = c1 AND c(k_{i+1}) = c2 }
```

This is the multiset of all observed flight times for the digraph `(c1, c2)`. From this multiset, the following statistics are computed (if `|D[c1][c2]| >= k_min = 5`):

| Statistic | Symbol | Definition |
|-----------|--------|------------|
| Count | `n_{c1,c2}` | `|D[c1][c2]|` |
| Mean | `mu_{c1,c2}` | `(1/n) * SUM F_i` |
| Standard deviation | `sigma_{c1,c2}` | `sqrt((1/(n-1)) * SUM (F_i - mu)^2)` |
| Median | `med_{c1,c2}` | 50th percentile |
| Skewness | `skew_{c1,c2}` | `(1/n) * SUM ((F_i - mu) / sigma)^3` |
| 10th percentile | `p10_{c1,c2}` | 10th percentile of the distribution |
| 90th percentile | `p90_{c1,c2}` | 90th percentile of the distribution |

The matrix is indexed over the character alphabet `A`. For English text, `A` includes lowercase letters `a-z`, digits `0-9`, common punctuation (`. , ; : ' " - ( ) [ ] { } / \ ! ? @ # $ % ^ & * _ + = < > ~`), whitespace (`SPACE`, `ENTER`, `TAB`), and navigation/editing keys (`BACKSPACE`, `DELETE`, `ARROW_LEFT`, `ARROW_RIGHT`, `ARROW_UP`, `ARROW_DOWN`). Total alphabet size: approximately 80-100 symbols, yielding a matrix of up to 10,000 cells (most of which will be sparse / below `k_min`).

**Trigraph Latency:**

For each ordered triple `(c1, c2, c3)`:

```
T[c1][c2][c3] = { (F(k_i, k_{i+1}), F(k_{i+1}, k_{i+2})) :
                   c(k_i) = c1, c(k_{i+1}) = c2, c(k_{i+2}) = c3 }
```

This is a multiset of 2-tuples. Due to the cubic growth of the trigraph space, only the top 200 most frequent trigraphs (by count) are retained. For each retained trigraph, the mean and standard deviation of each component flight time are computed (subject to `k_min`).

**Key Overlap (Roll Typing) Detection:**

```
O(k_i, k_{i+1}) = max(0, t_u(k_i) - t_d(k_{i+1}))
```

If `O > 0`, the keys overlapped (the typist pressed the next key before releasing the previous one). This is common in fast touch typists.

Computed statistics:
- `overlap_ratio`: fraction of consecutive key pairs with `O > 0`
- `mean_overlap_duration`: mean of `O` for overlapping pairs (ms)
- `overlap_by_hand`: overlap ratio partitioned by whether the key pair involves the same hand vs. different hands (requires a keyboard layout map; default: QWERTY)

**Hold Time Distribution:**

```
H_dist[c] = { H(k_i) : c(k_i) = c }
```

For each character `c` with `|H_dist[c]| >= k_min`, compute mean, standard deviation, and median of hold times.

Additionally, compute the global hold time distribution (all characters pooled): mean, standard deviation, median, 10th/90th percentiles, and a 20-bin histogram with bin edges at `[0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 120, 140, 160, 180, 200, 250, 300, 400, 500, 1000]` ms.

#### 5.1.2 Tier 2: Error and Revision Behavior

Error and revision features capture how the writer identifies and corrects mistakes. These patterns are strongly individual and extremely difficult to simulate because they reflect cognitive error-detection processes.

**Deletion Ratio:**

```
R_del = N_del / N_total
```

where `N_del` is the count of `InputEvent`s with `inputType` matching any deletion type (Section 4.1.3), and `N_total` is the total count of `InputEvent`s with insertion or deletion `inputType`.

- Typical range: 0.05--0.30 for human typists.
- Unit: dimensionless ratio (float64, [0, 1]).

**Deletion Burst Distribution:**

A *deletion burst* is a maximal contiguous subsequence of deletion `InputEvent`s not interrupted by any non-deletion `InputEvent` or by a pause exceeding `T_burst_break = 2000 ms`.

```
B_del = (b_1, b_2, ..., b_m)  where b_j = length of j-th deletion burst
```

Computed statistics:
- `burst_count`: `m` (total number of deletion bursts)
- `burst_length_mean`: mean of `B_del`
- `burst_length_std`: standard deviation of `B_del`
- `burst_length_max`: maximum burst length observed
- `burst_length_histogram`: 10-bin histogram with bin edges `[1, 2, 3, 4, 5, 6, 8, 10, 15, 20, inf)`

Example: A writer who tends to notice errors immediately and press Backspace once will have a distribution concentrated at `b = 1`. A writer who deletes entire words will show a peak around `b = 4-6`.

**Time-to-Correction:**

For each deletion event `d_j` that deletes content, define:

```
TTC(d_j) = t(d_j) - t(ins_j)
```

where `ins_j` is the most recent insertion event that produced the content being deleted by `d_j`. Determining `ins_j` requires maintaining a content model (mapping document positions to the events that produced them).

- If `ins_j` cannot be determined (e.g., deleting content from a prior session or pasted content), `TTC` is recorded as `null` for that deletion.
- Computed statistics (over non-null values, subject to `k_min`): mean, median, standard deviation, and a log-scale histogram with bin edges at `[0, 0.5, 1, 2, 5, 10, 30, 60, 120, 300, 600, inf)` seconds.

**Correction Locality:**

For each deletion event `d_j`, define:

```
CL(d_j) = |cursor_position(d_j) - document_end_position(d_j)|
```

This measures how far from the current end of the document the correction occurs (in characters). A value of 0 means the deletion is at the document's trailing edge (the most common case for immediate error correction).

Computed statistics:
- `correction_at_end_ratio`: fraction of deletions with `CL = 0`
- `correction_locality_histogram`: histogram of `CL` values with bin edges `[0, 1, 5, 10, 25, 50, 100, 250, 500, 1000, inf)` characters

**Undo/Redo Patterns:**

- `undo_count`: total `historyUndo` events in the window
- `redo_count`: total `historyRedo` events in the window
- `undo_redo_ratio`: `undo_count / max(1, undo_count + redo_count)`
- `undo_burst_mean`: mean length of consecutive undo sequences (analogous to deletion bursts)

#### 5.1.3 Tier 3: Composition Dynamics

Composition dynamics features capture the cognitive rhythm of writing, reflecting the planning and generation processes that produce text.

**Pause Taxonomy:**

Every inter-keystroke interval `IKI(k_i, k_{i+1}) = t_d(k_{i+1}) - t_d(k_i)` (equivalently, flight time) is classified into one of the following categories:

| Category | Label | IKI Range | Interpretation |
|----------|-------|-----------|---------------|
| Motor execution | `MOTOR` | `[0, 200) ms` | Ballistic keystroke production; no cognitive pause |
| Word boundary | `WORD_BOUNDARY` | `[200, 500) ms` | Brief hesitation at word boundaries or uncommon letter sequences |
| Sentence planning | `SENTENCE_PLAN` | `[500, 2000) ms` | Formulating the next clause or sentence |
| Paragraph planning | `PARA_PLAN` | `[2000, 10000) ms` | Structuring a new paragraph or reconsidering approach |
| Deep thinking | `DEEP_THINK` | `[10000, 30000) ms` | Extended reflection, re-reading, or conceptual reorganization |
| Break | `BREAK` | `[30000, +inf) ms` | User stepped away or engaged in a non-writing activity |

Note: These boundaries are defaults derived from typing research (see Section 5.4). Implementations MAY adjust boundaries based on a per-author calibration phase but MUST record the boundaries used.

Computed statistics:
- `pause_category_counts[category]`: count of IKIs in each category
- `pause_category_fractions[category]`: fraction of IKIs in each category
- `pause_category_mean_duration[category]`: mean IKI within each category (ms)
- `pause_category_std_duration[category]`: standard deviation of IKI within each category

**Pause-Position Correlation:**

For each pause of category `SENTENCE_PLAN` or longer, record the normalized document position `p = cursor_position / document_length` at the time of the pause.

- `pause_position_correlation`: Pearson correlation coefficient between pause duration and normalized document position. A positive value suggests longer pauses occur later in the document (potentially indicating increasing complexity or fatigue).
- `pause_position_histogram`: 2D histogram with pause category on one axis and normalized position (10 bins: `[0, 0.1), [0.1, 0.2), ..., [0.9, 1.0]`) on the other.

**Burst Analysis:**

A *typing burst* is a maximal contiguous subsequence of keystrokes where every inter-keystroke interval satisfies `IKI < T_burst = 500 ms`.

```
BURST(i, j) = (k_i, k_{i+1}, ..., k_j) where:
  - For all i <= m < j: IKI(k_m, k_{m+1}) < T_burst
  - IKI(k_{i-1}, k_i) >= T_burst  (or i = 1)
  - IKI(k_j, k_{j+1}) >= T_burst  (or j = n)
```

For each burst, compute:
- `burst_length`: number of keystrokes `j - i + 1`
- `burst_duration`: `t_d(k_j) - t_d(k_i)` (ms)
- `burst_internal_iki_mean`: mean IKI within the burst (ms)
- `burst_internal_iki_std`: standard deviation of IKI within the burst

Aggregate statistics across all bursts in a window:
- `burst_count`: total number of bursts
- `burst_length_mean`, `burst_length_std`, `burst_length_median`
- `burst_length_histogram`: bin edges `[1, 2, 3, 5, 8, 13, 21, 34, 55, 89, inf)`
- `burst_internal_speed_mean`: mean of per-burst `burst_internal_iki_mean`
- `burst_internal_speed_std`: standard deviation of per-burst `burst_internal_iki_mean`

Example: A typical proficient typist writing prose might exhibit bursts of 5--15 keystrokes (individual words) with internal IKI of 80--150 ms, separated by word-boundary or sentence-planning pauses.

**Pause-then-Burst Patterns:**

A *pause-burst pair* is a pause of category `SENTENCE_PLAN` or longer immediately followed by a typing burst.

```
PB(j) = (pause_duration_j, burst_length_j, burst_speed_j)
```

Computed statistics:
- `pb_count`: number of pause-burst pairs
- `pb_pause_burst_correlation`: Pearson correlation between `pause_duration` and `burst_length` across all pairs. A positive correlation suggests that longer thinking pauses lead to longer continuous output (the writer "loads up" a longer phrase mentally before typing).
- `pb_pause_burst_speed_correlation`: correlation between `pause_duration` and `burst_speed` (internal IKI mean).

#### 5.1.4 Tier 4: Navigation Behavior

Navigation features capture how the writer moves through and reviews the document, reflecting revision strategy and compositional approach.

**Nonlinear Editing Score:**

```
NES = N_nonlinear / N_total_edits
```

where `N_nonlinear` is the count of insertion or deletion events where the cursor position is not within 2 characters of the document's current trailing edge, and `N_total_edits` is the total count of insertion and deletion events.

- Range: `[0, 1]`
- A value near 0 indicates predominantly linear (append-only) writing.
- A value near 0.3--0.5 indicates significant revision/editing behavior.
- Values above 0.5 are typical of heavy editing passes on existing text.

**Cursor Jump Distance Distribution:**

For each pair of consecutive editing operations at positions `p_i` and `p_{i+1}`:

```
J(i) = |p_{i+1} - p_i|  (in characters)
```

Excluding consecutive operations where `J = 0` or `J = 1` (no jump; normal sequential typing/deletion).

Computed statistics (for `J > 1`):
- `jump_count`: number of cursor jumps
- `jump_distance_mean`, `jump_distance_std`, `jump_distance_median`
- `jump_distance_histogram`: bin edges `[2, 5, 10, 25, 50, 100, 250, 500, 1000, inf)` characters
- `jump_rate`: `jump_count / window_duration_seconds`

**Scroll Patterns:**

Derived from `WheelEvent` data:

- `scroll_event_count`: total scroll events in window
- `scroll_rate`: `scroll_event_count / window_duration_seconds`
- `scroll_direction_ratio`: `count(deltaY < 0) / scroll_event_count` (fraction of upward scrolls; higher values indicate more re-reading)
- `scroll_distance_total`: `SUM |deltaY|` (total pixels scrolled)
- `scroll_burst_count`: number of scroll bursts (consecutive scroll events within 500 ms of each other)

**Section Revisit Frequency:**

The document is divided into `N_sections = 10` equal-length sections by character count. For each editing operation, the section in which it occurs is recorded.

```
revisit_entropy = - SUM_s (p_s * log2(p_s))
```

where `p_s` is the fraction of editing operations in section `s`. Maximum entropy (`log2(10) ~= 3.32`) indicates uniform editing across the document; low entropy indicates editing concentrated in one section.

- `revisit_entropy`: float64, bits
- `revisit_section_histogram`: count of editing operations per section (10-element vector)

#### 5.1.5 Tier 5: Linguistic-Temporal Correlation

These features bridge the gap between what is typed and how it is typed. They require ephemeral access to the character stream and produce only aggregate statistics.

**Vocabulary-Speed Correlation:**

For each word typed (a burst of alphabetic characters delimited by spaces/punctuation), compute:
- The word's frequency rank `r` in a standard frequency list (e.g., COCA top 5000 for English; the specific list MUST be identified in the implementation's configuration)
- The mean IKI of the keystrokes composing that word: `speed(w)`

Then compute:
- `vocab_speed_correlation`: Spearman rank correlation between `r` and `speed(w)` across all words in the window. A negative correlation (common words typed faster) is expected for humans and reflects automaticity.
- `vocab_speed_by_band`: mean typing speed for words in frequency bands:
  - Band 1: rank 1--100 (most common)
  - Band 2: rank 101--500
  - Band 3: rank 501--2000
  - Band 4: rank 2001--5000
  - Band 5: rank 5001+ or not in list (rare/specialized)

Example: A typical human shows mean IKI of ~100 ms for Band 1 words, increasing to ~140 ms for Band 5 words.

**Privacy Implementation Note:** The word frequency lookup is performed against a fixed public word list. The lookup key (the word) is ephemeral. Only the frequency band assignment and the timing are used. The words themselves are not retained.

**Sentence Complexity vs. Preceding Pause Duration:**

For each sentence (delimited by `.`, `!`, `?` followed by a space or paragraph break), compute:
- `sentence_length`: word count of the sentence
- `preceding_pause`: the IKI immediately before the first character of the sentence

Then compute:
- `complexity_pause_correlation`: Pearson correlation between `sentence_length` and `preceding_pause` across all sentences in the window.
- Expected human behavior: positive correlation (longer sentences are preceded by longer planning pauses).

**Error Rate by Word Frequency:**

- `error_rate_by_band[band]`: for each frequency band, the ratio of words that contained at least one within-word deletion to the total words in that band.
- Expected human behavior: error rate increases for less frequent words.

**Content Arrival Mode:**

For each text segment added to the document, classify its arrival:
- `typed`: produced by `insertText` input events with corresponding `keydown` events
- `pasted`: produced by `insertFromPaste`
- `dropped`: produced by `insertFromDrop`
- `autocorrected`: produced by `insertReplacementText`
- `other`: any other insertion mechanism

Computed statistics:
- `arrival_mode_fractions[mode]`: fraction of total inserted characters arriving by each mode
- `paste_event_count`: total number of paste operations
- `paste_size_mean`: mean characters per paste operation
- `paste_size_histogram`: bin edges `[1, 10, 50, 100, 500, 1000, 5000, inf)` characters

#### 5.1.6 Tier 6: Session Macro-Structure

Session macro-structure features capture patterns at the scale of minutes to hours, reflecting the writer's work habits and cognitive endurance.

**Warm-up Detection:**

The first `T_warmup = 120 seconds` (2 minutes) of a session is analyzed separately:

- `warmup_iki_mean`: mean IKI during the warm-up period
- `warmup_iki_end`: mean IKI during the second minute of the warm-up
- `warmup_ratio`: `warmup_iki_mean / session_iki_mean`
- A `warmup_ratio > 1.0` indicates the writer starts slowly and accelerates (typical).

**Fatigue Signature:**

Divide the session into 10 equal time slices. For each slice `s`:
- `fatigue_speed[s]`: mean IKI for slice `s`
- `fatigue_error_rate[s]`: deletion ratio for slice `s`
- `fatigue_pause_fraction[s]`: fraction of time spent in pauses >= `SENTENCE_PLAN` for slice `s`

Then compute:
- `fatigue_speed_slope`: linear regression slope of `fatigue_speed[s]` over `s`. Positive slope (increasing IKI) indicates fatigue-related slowdown.
- `fatigue_error_slope`: linear regression slope of `fatigue_error_rate[s]` over `s`. Positive slope indicates increasing error rate.
- `fatigue_speed_r_squared`: R^2 of the speed regression (how linear the fatigue effect is).

**Break Patterns:**

Derived from `BREAK` pauses (IKI >= 30 seconds) and session pause/resume events:

- `break_count`: total number of breaks
- `break_duration_mean`: mean break duration (seconds)
- `break_duration_std`: standard deviation of break duration
- `break_interval_mean`: mean time between breaks (seconds)
- `inter_break_productivity`: mean keystrokes per second in the intervals between breaks

**Session Shape Profile:**

Compute the keystroke rate (keystrokes per second) in non-overlapping 60-second bins across the entire session:

```
R[t] = count of keystrokes in [t, t+60) / 60.0    (keystrokes/second)
```

The session shape profile is the vector `R = (R[0], R[1], ..., R[floor(D/60)])` where `D` is the session duration in seconds.

Computed statistics from the shape profile:
- `shape_mean`: mean of `R`
- `shape_std`: standard deviation of `R`
- `shape_cv`: coefficient of variation `shape_std / shape_mean`
- `shape_autocorrelation_lag1`: autocorrelation of `R` at lag 1 (captures whether consecutive minutes have correlated activity)
- `shape_entropy`: Shannon entropy of the normalized `R` distribution (higher = more uniform activity; lower = bursty)
- `shape_max_inactive_streak`: longest consecutive run of `R[t] = 0`

### 5.2 Feature Vector Specification

The complete feature vector `F` for a single extraction window is defined as the following structured record. All fields use IEEE 754 double-precision floating-point (float64) unless otherwise noted. Null values (insufficient observations) are represented as `NaN`.

#### 5.2.1 Schema Definition

```
struct FeatureVector {
  // === METADATA (not part of the behavioral signature) ===
  version:            uint16       // Protocol version (current: 1)
  window_index:       uint32       // 0-based index of this window in the session
  window_start_ms:    float64      // Timestamp of window start (ms, session-relative)
  window_end_ms:      float64      // Timestamp of window end (ms, session-relative)
  keystroke_count:    uint32       // Total keystrokes in this window
  event_count:        uint32       // Total events (all types) in this window
  is_partial:         bool         // True if keystroke_count < W_min

  // === TIER 1: TEMPORAL MICROSTRUCTURE ===
  flight_time_mean:                float64   // ms
  flight_time_std:                 float64   // ms
  flight_time_median:              float64   // ms
  flight_time_skewness:            float64   // dimensionless
  flight_time_p10:                 float64   // ms, 10th percentile
  flight_time_p90:                 float64   // ms, 90th percentile
  flight_time_histogram:           float64[20]  // 20-bin histogram (counts)
    // Bin edges: [0,50,75,100,125,150,175,200,250,300,350,
    //             400,500,600,800,1000,1500,2000,5000,30000,inf)

  hold_time_mean:                  float64   // ms
  hold_time_std:                   float64   // ms
  hold_time_median:                float64   // ms
  hold_time_histogram:             float64[20]  // 20-bin histogram (counts)
    // Bin edges: [0,10,20,30,40,50,60,70,80,90,100,
    //             120,140,160,180,200,250,300,400,500,1000]

  digraph_matrix_entries:          DiGraphEntry[]  // Variable length, see below
  trigraph_entries:                 TriGraphEntry[] // Top 200 by count

  overlap_ratio:                   float64   // [0, 1]
  mean_overlap_duration:           float64   // ms (NaN if overlap_ratio = 0)
  overlap_same_hand_ratio:         float64   // [0, 1], NaN if no overlap
  overlap_cross_hand_ratio:        float64   // [0, 1], NaN if no overlap

  // === TIER 2: ERROR AND REVISION BEHAVIOR ===
  deletion_ratio:                  float64   // [0, 1]
  deletion_burst_count:            uint32
  deletion_burst_length_mean:      float64
  deletion_burst_length_std:       float64
  deletion_burst_length_max:       uint32
  deletion_burst_length_histogram: float64[10]  // 10-bin histogram
    // Bin edges: [1,2,3,4,5,6,8,10,15,20,inf)

  ttc_mean:                        float64   // seconds (time-to-correction)
  ttc_median:                      float64   // seconds
  ttc_std:                         float64   // seconds
  ttc_histogram:                   float64[11] // 11-bin log-scale histogram
    // Bin edges: [0,0.5,1,2,5,10,30,60,120,300,600,inf) seconds

  correction_at_end_ratio:         float64   // [0, 1]
  correction_locality_histogram:   float64[10] // 10-bin histogram
    // Bin edges: [0,1,5,10,25,50,100,250,500,1000,inf) characters

  undo_count:                      uint32
  redo_count:                      uint32
  undo_redo_ratio:                 float64   // [0, 1]
  undo_burst_mean:                 float64

  // === TIER 3: COMPOSITION DYNAMICS ===
  pause_category_counts:           uint32[6]    // [MOTOR, WORD_BOUNDARY, SENTENCE_PLAN,
                                                //  PARA_PLAN, DEEP_THINK, BREAK]
  pause_category_fractions:        float64[6]   // corresponding fractions
  pause_category_mean_duration:    float64[6]   // ms per category
  pause_category_std_duration:     float64[6]   // ms per category

  pause_position_correlation:      float64      // Pearson r
  pause_position_histogram:        float64[60]  // 6 categories x 10 position bins

  burst_count:                     uint32
  burst_length_mean:               float64
  burst_length_std:                float64
  burst_length_median:             float64
  burst_length_histogram:          float64[10]  // Fibonacci-inspired bin edges
    // Bin edges: [1,2,3,5,8,13,21,34,55,89,inf)
  burst_internal_speed_mean:       float64      // ms (mean of per-burst mean IKI)
  burst_internal_speed_std:        float64      // ms

  pb_count:                        uint32
  pb_pause_burst_correlation:      float64
  pb_pause_burst_speed_correlation:float64

  // === TIER 4: NAVIGATION BEHAVIOR ===
  nonlinear_editing_score:         float64      // [0, 1]
  jump_count:                      uint32
  jump_distance_mean:              float64      // characters
  jump_distance_std:               float64      // characters
  jump_distance_median:            float64      // characters
  jump_distance_histogram:         float64[9]   // 9-bin histogram
    // Bin edges: [2,5,10,25,50,100,250,500,1000,inf) characters
  jump_rate:                       float64      // jumps per second

  scroll_event_count:              uint32
  scroll_rate:                     float64      // events per second
  scroll_direction_ratio:          float64      // [0, 1] (fraction upward)
  scroll_distance_total:           float64      // pixels
  scroll_burst_count:              uint32

  revisit_entropy:                 float64      // bits
  revisit_section_histogram:       uint32[10]   // counts per section

  // === TIER 5: LINGUISTIC-TEMPORAL CORRELATION ===
  vocab_speed_correlation:         float64      // Spearman rho
  vocab_speed_by_band:             float64[5]   // mean IKI per frequency band (ms)

  complexity_pause_correlation:    float64      // Pearson r

  error_rate_by_band:              float64[5]   // [0, 1] per frequency band

  arrival_mode_fractions:          float64[5]   // [typed, pasted, dropped,
                                                //  autocorrected, other]
  paste_event_count:               uint32
  paste_size_mean:                 float64      // characters
  paste_size_histogram:            float64[7]   // 7-bin histogram
    // Bin edges: [1,10,50,100,500,1000,5000,inf) characters

  // === TIER 6: SESSION MACRO-STRUCTURE ===
  warmup_iki_mean:                 float64      // ms
  warmup_iki_end:                  float64      // ms (second minute)
  warmup_ratio:                    float64      // dimensionless

  fatigue_speed:                   float64[10]  // mean IKI per time slice
  fatigue_error_rate:              float64[10]  // deletion ratio per slice
  fatigue_pause_fraction:          float64[10]  // fraction in long pauses per slice
  fatigue_speed_slope:             float64      // ms per slice (regression slope)
  fatigue_error_slope:             float64      // ratio per slice
  fatigue_speed_r_squared:         float64      // [0, 1]

  break_count:                     uint32
  break_duration_mean:             float64      // seconds
  break_duration_std:              float64      // seconds
  break_interval_mean:             float64      // seconds
  inter_break_productivity:        float64      // keystrokes per second

  shape_mean:                      float64      // keystrokes per second
  shape_std:                       float64      // keystrokes per second
  shape_cv:                        float64      // dimensionless
  shape_autocorrelation_lag1:      float64      // [-1, 1]
  shape_entropy:                   float64      // bits
  shape_max_inactive_streak:       uint32       // count of consecutive 0-rate minutes
}

struct DiGraphEntry {
  c1:    uint8     // Character index in alphabet A
  c2:    uint8     // Character index in alphabet A
  count: uint32    // Number of observations (>= k_min)
  mean:  float64   // ms
  std:   float64   // ms
  median:float64   // ms
  skew:  float64   // dimensionless
  p10:   float64   // ms
  p90:   float64   // ms
}

struct TriGraphEntry {
  c1:       uint8     // Character index in alphabet A
  c2:       uint8     // Character index in alphabet A
  c3:       uint8     // Character index in alphabet A
  count:    uint32    // Number of observations (>= k_min)
  mean_f1:  float64   // Mean of first flight time (ms)
  std_f1:   float64   // Std of first flight time (ms)
  mean_f2:  float64   // Mean of second flight time (ms)
  std_f2:   float64   // Std of second flight time (ms)
}
```

#### 5.2.2 Serialization

The feature vector MUST be serialized in a canonical binary format for hashing and cryptographic commitment:

1. All multi-byte numeric values are encoded in **little-endian** byte order.
2. The serialization order follows the field order in the schema definition above (depth-first for nested structures).
3. Variable-length arrays (digraph entries, trigraph entries) are preceded by a `uint32` length prefix.
4. `NaN` values are encoded as the IEEE 754 canonical `NaN` bit pattern: `0x7FF8000000000000`.
5. Boolean values are encoded as `uint8` (0 = false, 1 = true).
6. The total serialized size for a typical window (with ~300 digraph entries and 200 trigraph entries) is approximately **12--15 KB**.

#### 5.2.3 Feature Vector Versioning

The `version` field (uint16) encodes the protocol version. The current version is `1`. Future versions MAY add fields to the end of the schema but MUST NOT reorder or remove existing fields. If fields are deprecated, they are retained but filled with `NaN`. This ensures backward compatibility: a verifier supporting version `N` can validate proofs produced by version `M <= N`.

### 5.3 Windowed Extraction

#### 5.3.1 Window Parameters

| Parameter | Symbol | Default Value | Description |
|-----------|--------|---------------|-------------|
| Window duration | `W_dur` | 300,000 ms (5 minutes) | Time span of each extraction window |
| Window stride | `W_stride` | 60,000 ms (1 minute) | Time between successive window starts |
| Minimum keystrokes | `W_min` | 100 | Minimum keystrokes for a window to be considered valid (non-partial) |
| Overlap ratio | -- | `1 - W_stride/W_dur = 0.8` | Fraction of overlap between adjacent windows |

#### 5.3.2 Window Definition

Window `w_i` covers the time interval `[T_0 + i * W_stride, T_0 + i * W_stride + W_dur)` where `T_0` is the session's monotonic epoch.

```
w_i = { e in E : T_0 + i * W_stride <= t(e) < T_0 + i * W_stride + W_dur }
```

Windows overlap: event `e` with timestamp `t(e)` may belong to multiple windows. Feature extraction operates independently on each window. This is by design: the overlapping windows provide temporal smoothing and ensure that behavioral patterns spanning a window boundary are captured.

#### 5.3.3 Window Lifecycle

```
For each window w_i:
  1. ACCUMULATE: Events are added to w_i's working set as they arrive,
     if their timestamp falls within w_i's interval.
  2. CLOSE: When the session's current time exceeds
     T_0 + i * W_stride + W_dur (or session terminates), w_i is closed.
  3. EXTRACT: Feature extraction (Section 5.1) is applied to w_i's events.
  4. VALIDATE: If keystroke_count < W_min, the window is marked as partial.
     Partial windows are included in the session summary but are flagged and
     given reduced weight in document-level aggregation.
  5. COMMIT: The feature vector for w_i is serialized, hashed, and committed
     to the incremental commitment structure (see Section [future]).
  6. PRUNE: Events that belong ONLY to w_i (not to any subsequent open window)
     are eligible for ephemeral destruction (Section 4.2.4). Events that also
     belong to w_{i+1} (or later) are retained.
```

**Pruning Rule (formal):**

Event `e` with timestamp `t(e)` may be destroyed after window `w_i` is committed if and only if there is no open window `w_j` (`j > i`) such that `t(e) >= T_0 + j * W_stride`.

Equivalently: `e` is safe to destroy when the most recently opened window's start time exceeds `t(e)`. Given the default parameters (stride = 1 minute, duration = 5 minutes), an event survives in memory for at most 5 minutes after it is generated (the duration of the last window it could belong to) plus the computation time for feature extraction.

#### 5.3.4 Window-to-Session Aggregation

When the session terminates, session-level features are computed from the sequence of window-level feature vectors `(F_{w_0}, F_{w_1}, ..., F_{w_m})`.

**Aggregation Rules by Field Type:**

| Field Type | Aggregation Method |
|-----------|-------------------|
| Counts (`uint32`) | Sum across all windows |
| Ratios / fractions (`float64`, `[0, 1]`) | Weighted mean, weight = `keystroke_count` of window |
| Mean values (timing) | Weighted mean, weight = `keystroke_count` |
| Standard deviations | Pooled standard deviation: `sqrt(SUM(w_i * (std_i^2 + (mean_i - grand_mean)^2)) / SUM(w_i))` |
| Histograms | Element-wise sum of bin counts |
| Correlations | Recomputed from the pooled data (not averaged); if this is infeasible, use Fisher z-transformation: `z = atanh(r)`, compute weighted mean of `z` values, then `r_agg = tanh(z_mean)` |
| Digraph/Trigraph matrices | Merge entries: sum counts, recompute statistics from pooled counts using the identity for combining means/variances from subgroups |
| Session shape profile | Computed directly from session-level data (not from windows) |
| Fatigue features | Computed directly from session-level time slices (not from windows) |
| Warm-up features | Computed only from events in the first 120 seconds of the session |

The session-level feature vector has the same schema as the window-level feature vector, with the following differences:
- `window_index` is set to `0xFFFFFFFF` (sentinel value indicating session-level)
- `window_start_ms` = 0
- `window_end_ms` = session duration in ms
- `is_partial` = false (session-level is always considered complete if any valid window exists)

### 5.4 Human Baseline Model

#### 5.4.1 Purpose

The Human Baseline Model (HBM) defines the statistical boundaries of plausible human keystroke behavior. It serves two purposes:

1. **Anomaly detection:** Flagging writing sessions whose behavioral features fall outside the range of known human behavior, which may indicate automated generation or replay attacks.
2. **Skill-level contextualization:** Normalizing features relative to the author's demonstrated skill level to prevent false positives from unusual but legitimate typing patterns.

#### 5.4.2 Baseline Parameter Ranges

The following ranges are derived from the keystroke dynamics literature, primarily Killourhy and Maxion (2009, "Why Did My Detector Get 85% in the ROC Curve?"), Monaco et al. (2013, "Developing a Keystroke Biometric System for Continual Authentication of Computer Users"), and Dhakal et al. (2018, "Observations on Typing from 136 Million Keystrokes"). These ranges represent 99% population coverage (0.5th to 99.5th percentile across studied populations).

**Tier 1 Baselines:**

| Feature | Hunt-and-Peck | Average Typist | Touch Typist | Professional |
|---------|--------------|----------------|--------------|-------------|
| Flight time mean (ms) | 300--800 | 150--350 | 80--200 | 50--130 |
| Flight time std (ms) | 100--400 | 60--200 | 30--100 | 20--60 |
| Hold time mean (ms) | 80--200 | 70--150 | 50--120 | 40--100 |
| Hold time std (ms) | 30--100 | 20--70 | 15--50 | 10--40 |
| Overlap ratio | 0.00--0.05 | 0.01--0.15 | 0.05--0.35 | 0.10--0.50 |
| WPM equivalent* | 10--25 | 25--50 | 50--80 | 80--150+ |

*WPM (words per minute) is computed as `(keystroke_count / 5) / (active_time_minutes)` where active_time excludes pauses > 2 seconds. This is provided for interpretability; it is not a feature in the vector.

**Tier 2 Baselines:**

| Feature | Plausible Human Range |
|---------|-----------------------|
| Deletion ratio | 0.02--0.40 |
| Deletion burst length mean | 1.0--8.0 |
| Time-to-correction mean (s) | 0.3--60.0 |
| Correction at end ratio | 0.50--0.98 |
| Undo count per 1000 keystrokes | 0--15 |

**Tier 3 Baselines:**

| Feature | Plausible Human Range |
|---------|-----------------------|
| Pause fraction (MOTOR) | 0.40--0.85 |
| Pause fraction (WORD_BOUNDARY) | 0.10--0.35 |
| Pause fraction (SENTENCE_PLAN) | 0.03--0.20 |
| Pause fraction (PARA_PLAN) | 0.01--0.10 |
| Burst length mean | 2.0--25.0 keystrokes |
| Burst internal IKI mean | 50--300 ms |

**Tier 5 Baselines:**

| Feature | Plausible Human Range |
|---------|-----------------------|
| Vocab-speed correlation (Spearman) | -0.6 to -0.05 (should be negative) |
| Complexity-pause correlation (Pearson) | 0.0 to 0.7 (should be non-negative) |
| Typed fraction (arrival mode) | 0.70--1.00 |

#### 5.4.3 Skill-Level Classification

Before comparing features to baselines, the author's skill level is estimated from the current session data. The classification uses a simple decision tree:

```
FUNCTION ClassifySkillLevel(F):
  wpm = EstimateWPM(F)
  IF wpm < 25:
    RETURN HUNT_AND_PECK
  ELSE IF wpm < 50:
    RETURN AVERAGE
  ELSE IF wpm < 80:
    RETURN TOUCH_TYPIST
  ELSE:
    RETURN PROFESSIONAL

  // Secondary signals (used to resolve ambiguous cases):
  //   overlap_ratio > 0.10 strongly suggests TOUCH_TYPIST or above
  //   hold_time_std < 30 ms strongly suggests PROFESSIONAL
  //   home_row_usage_ratio > 0.6 suggests TOUCH_TYPIST or above
```

The skill level determines which column of the baseline table is used for anomaly thresholds.

#### 5.4.4 Content-Type Adjustment

Different content types produce different behavioral signatures even from the same author. The HBM applies content-type adjustment factors:

| Content Type | Detection Heuristic | Adjustment |
|-------------|-------------------|------------|
| **Prose** (default) | Majority of input is natural-language words | No adjustment (baselines calibrated for prose) |
| **Code** | High frequency of `{`, `}`, `;`, `(`, `)`, indentation; presence of `Tab` keystrokes; camelCase/snake_case patterns | Flight time baselines widened by 1.5x; deletion ratio baseline widened to [0.05, 0.50]; pause fraction (SENTENCE_PLAN) widened |
| **Casual/Chat** | Short document length (< 500 characters); high frequency of informal markers (abbreviations, emoji shortcodes) | Flight time baselines narrowed; deletion ratio may be lower |
| **Data entry** | Repetitive structure; high Tab usage; numeric content predominance | Flight time baselines narrowed; low pause fraction for PARA_PLAN and DEEP_THINK |

Content type is detected automatically from the feature data and ephemeral content analysis. The detected content type is recorded in the session metadata.

#### 5.4.5 Anomaly Detection

An anomaly score is computed for each feature `f_i` in the feature vector:

```
a(f_i) = |f_i - mu_baseline(f_i)| / sigma_baseline(f_i)
```

where `mu_baseline` and `sigma_baseline` are the mean and standard deviation from the appropriate skill-level and content-type baseline distribution.

The aggregate anomaly score for a window is:

```
A(w) = (1 / |F_valid|) * SUM_{f_i in F_valid} min(a(f_i), a_cap)
```

where `F_valid` is the set of non-NaN features and `a_cap = 10.0` prevents any single outlier feature from dominating the score.

**Anomaly Thresholds:**

| Aggregate Anomaly Score | Interpretation |
|------------------------|----------------|
| `A < 2.0` | Normal human behavior |
| `2.0 <= A < 3.5` | Unusual but plausible; may indicate atypical conditions (e.g., unfamiliar keyboard, injury, intoxication) |
| `3.5 <= A < 5.0` | Suspicious; warrants additional verification signals |
| `A >= 5.0` | Strongly anomalous; behavioral proof should be flagged |

These thresholds are calibrated to achieve a false positive rate of approximately 1% for `A >= 3.5` and 0.1% for `A >= 5.0` across the reference population.

**Critical Machine-Detectable Signatures:**

The following patterns are strong indicators of non-human generation and are checked independently of the aggregate anomaly score:

1. **Zero-variance timing:** `flight_time_std < 5 ms` across more than 50 consecutive keystrokes (mechanical replay).
2. **Impossible speed:** `flight_time_mean < 30 ms` sustained for more than 10 seconds (exceeds human neuromuscular limits for arbitrary text).
3. **No pauses:** `pause_category_fractions[SENTENCE_PLAN] + pause_category_fractions[PARA_PLAN] + pause_category_fractions[DEEP_THINK] < 0.01` in a window with > 500 keystrokes (humans cannot compose non-trivial text without planning pauses).
4. **No errors:** `deletion_ratio < 0.005` in a window with > 300 keystrokes (even expert typists produce occasional errors in real composition).
5. **Missing vocabulary-speed effect:** `vocab_speed_correlation > -0.01` (humans universally type common words faster than rare words).
6. **Uniform digraph timing:** All digraph means within 10 ms of each other across > 20 distinct digraphs (human motor execution is strongly key-pair dependent).
7. **No hold-time variation:** `hold_time_std < 5 ms` (impossible given the biomechanics of finger press/release).

If any of these critical checks fail, the window is flagged with `critical_anomaly = true` regardless of the aggregate score.

### 5.5 Cross-Document Consistency Model

#### 5.5.1 Purpose

The Cross-Document Consistency Model (CDCM) establishes and maintains a behavioral profile for each author across multiple documents and sessions. It enables:

1. **Progressive trust:** Confidence in a claimed author identity increases as more documents exhibit consistent behavioral signatures.
2. **Anomaly detection:** Detecting when a document attributed to a known author exhibits a statistically different behavioral profile.
3. **Pseudonymous continuity:** An author can prove that multiple documents were written by the same person without revealing their real-world identity.

#### 5.5.2 Author Behavioral Profile

An Author Behavioral Profile (ABP) is a statistical model constructed from the session-level feature vectors of all documents attributed to a given author identity.

```
struct AuthorBehavioralProfile {
  author_id:            bytes32      // Opaque identifier (e.g., hash of World ID commitment)
  profile_version:      uint32       // Incremented on each update
  document_count:       uint32       // Number of documents incorporated
  total_keystrokes:     uint64       // Cumulative keystrokes across all documents
  total_active_time_ms: uint64       // Cumulative active writing time

  // Per-feature statistics (computed from session-level feature vectors):
  feature_means:        float64[N_features]   // Running mean of each scalar feature
  feature_variances:    float64[N_features]   // Running variance (Welford's algorithm)
  feature_mins:         float64[N_features]   // Observed minimum
  feature_maxs:         float64[N_features]   // Observed maximum

  // Digraph profile (aggregated across all documents):
  digraph_means:        DiGraphProfile[]      // Mean flight time per digraph
  digraph_variances:    DiGraphProfile[]      // Variance of flight time per digraph
  digraph_counts:       DiGraphProfile[]      // Total observations per digraph

  // Metadata:
  content_type_distribution: float64[4]       // Fraction of documents by content type
  skill_level_history:       uint8[]          // Skill level per document
  last_updated:              uint64           // Unix timestamp of last profile update
}

struct DiGraphProfile {
  c1:       uint8
  c2:       uint8
  mean:     float64   // ms
  variance: float64   // ms^2
  count:    uint64    // total observations across all documents
}
```

#### 5.5.3 Profile Update Procedure

When a new document's session feature vector `F_new` is incorporated into an existing ABP:

```
PROCEDURE UpdateProfile(ABP, F_new, weight):
  // weight = number of valid windows in the new session
  // Use Welford's online algorithm for numerically stable running statistics

  ABP.document_count += 1
  ABP.total_keystrokes += F_new.keystroke_count
  ABP.total_active_time_ms += (F_new.window_end_ms - F_new.window_start_ms)

  FOR EACH scalar feature f_i in F_new:
    IF f_i is not NaN:
      n = ABP.document_count  // (or a feature-specific observation counter)
      delta = f_i - ABP.feature_means[i]
      ABP.feature_means[i] += delta / n
      delta2 = f_i - ABP.feature_means[i]
      ABP.feature_variances[i] += delta * delta2

  // Digraph profile update:
  FOR EACH digraph entry (c1, c2, count, mean, std) in F_new.digraph_matrix_entries:
    existing = ABP.digraph_lookup(c1, c2)
    IF existing is null:
      ABP.digraph_insert(c1, c2, mean, std^2, count)
    ELSE:
      // Combine two groups with known means, variances, and counts:
      n1 = existing.count
      n2 = count
      combined_mean = (n1 * existing.mean + n2 * mean) / (n1 + n2)
      combined_var = ((n1-1)*existing.variance + (n2-1)*std^2) / (n1+n2-1)
                   + (n1*n2*(existing.mean - mean)^2) / ((n1+n2)*(n1+n2-1))
      existing.mean = combined_mean
      existing.variance = combined_var
      existing.count = n1 + n2

  ABP.profile_version += 1
  ABP.last_updated = current_unix_timestamp()
```

#### 5.5.4 Consistency Score

The consistency score `C(F_new, ABP)` measures how well a new document's feature vector matches the author's established profile. It is defined as:

```
C(F_new, ABP) = 1 - (D_M(F_new, ABP) / D_threshold)
```

where `D_M` is the Mahalanobis-inspired distance and `D_threshold` is a normalization constant.

**Distance Computation:**

```
D_M(F_new, ABP) = sqrt(
  (1 / |F_comparable|) *
  SUM_{f_i in F_comparable} (
    (f_i_new - ABP.feature_means[i])^2 /
    max(ABP.feature_variances[i] / (ABP.document_count - 1), epsilon^2)
  )
)
```

where:
- `F_comparable` is the set of features that are non-NaN in both `F_new` and the ABP, AND have `ABP.feature_variances[i] > 0` (i.e., there is observed variation).
- `epsilon = 1.0` is a minimum standard deviation floor to prevent division by near-zero variance when the profile has very few documents.

Note: This is a simplified diagonal approximation of the full Mahalanobis distance (assuming feature independence). A full covariance matrix approach is more powerful but requires significantly more documents to estimate reliably. Implementations MAY upgrade to full Mahalanobis when `ABP.document_count >= 30`.

**Digraph Distance (supplementary):**

```
D_digraph(F_new, ABP) = sqrt(
  (1 / |G_comparable|) *
  SUM_{(c1,c2) in G_comparable} (
    (F_new.digraph[c1][c2].mean - ABP.digraph[c1][c2].mean)^2 /
    max(ABP.digraph[c1][c2].variance, epsilon_d^2)
  )
)
```

where `G_comparable` is the set of digraphs present in both with `count >= k_min` in both, and `epsilon_d = 5.0 ms`.

**Combined Consistency Score:**

```
C_combined = alpha * C_features + (1 - alpha) * C_digraph
```

where `alpha = 0.6` (features contribute 60%, digraphs 40%).

**Interpretation:**

| Score Range | Interpretation |
|------------|----------------|
| `C >= 0.80` | Strong consistency (highly likely same author) |
| `0.60 <= C < 0.80` | Moderate consistency (consistent with same author under variable conditions) |
| `0.40 <= C < 0.60` | Weak consistency (possible same author with significant behavioral change) |
| `C < 0.40` | Inconsistent (unlikely same author, or significant confounding factors) |

#### 5.5.5 Progressive Trust

The confidence in an author's behavioral profile increases with the number and diversity of incorporated documents. Progressive trust is formalized as:

```
Trust(ABP) = 1 - exp(-lambda * E(ABP))
```

where:
- `lambda = 0.3` (trust accumulation rate)
- `E(ABP)` is the *effective document count*, defined as:

```
E(ABP) = SUM_{j=1}^{document_count} w_j * q_j
```

where:
- `w_j = min(1, valid_windows(S_j) / 10)` -- weight based on document length (documents with >= 10 valid windows receive full weight; shorter documents receive proportionally less)
- `q_j = C(F_j, ABP_{j-1})` for `j >= 2`; `q_1 = 0.5` (first document gets half weight since there is no prior profile to compare against)

**Trust Level Thresholds:**

| Effective Document Count | Trust Value | Trust Level |
|--------------------------|-------------|-------------|
| E = 1 | 0.26 | Nascent |
| E = 3 | 0.59 | Developing |
| E = 5 | 0.78 | Established |
| E = 10 | 0.95 | Strong |
| E = 20 | 0.998 | Authoritative |

Trust is reported alongside the behavioral proof and can be used by consumers (e.g., content platforms, publishers) to calibrate their confidence in authorship attribution.

#### 5.5.6 Anomaly Detection for Known Authors

When a new document is attributed to an author with an existing ABP, and the consistency score is below the expected range, the protocol generates an anomaly report:

```
PROCEDURE CheckAuthorConsistency(F_new, ABP):
  C = ComputeConsistencyScore(F_new, ABP)

  IF ABP.document_count < 3:
    // Insufficient history for meaningful anomaly detection
    RETURN { status: "insufficient_history", score: C }

  // Compute the expected consistency based on profile maturity
  expected_C = 0.60 + 0.15 * Trust(ABP)  // Higher trust -> higher expectation

  IF C >= expected_C:
    RETURN { status: "consistent", score: C }
  ELSE IF C >= expected_C - 0.20:
    RETURN {
      status: "mild_deviation",
      score: C,
      deviating_features: TopNDeviatingFeatures(F_new, ABP, n=5),
      possible_explanations: InferExplanations(deviating_features)
    }
  ELSE:
    RETURN {
      status: "significant_deviation",
      score: C,
      deviating_features: TopNDeviatingFeatures(F_new, ABP, n=10),
      possible_explanations: InferExplanations(deviating_features),
      recommendation: "additional_verification_recommended"
    }
```

**`TopNDeviatingFeatures`** returns the `n` features with the largest standardized deviation `|f_i - mu_i| / sigma_i` from the ABP.

**`InferExplanations`** maps deviating feature patterns to plausible explanations:

| Deviation Pattern | Possible Explanation |
|-------------------|---------------------|
| Uniformly slower flight times, higher hold times | Different keyboard or device |
| Higher error rate, lower burst length | Unfamiliar topic or fatigue |
| Different pause distribution (more DEEP_THINK) | More complex or unfamiliar content |
| Different digraph timing with consistent structure | Changed keyboard layout |
| All features shifted uniformly | Different physical conditions (injury, posture) |
| Fundamentally different microstructure | Likely different author |

#### 5.5.7 Profile Storage and Privacy

The ABP is stored encrypted, keyed to the author's identity credential. The ABP itself does not contain any text content; it consists entirely of statistical aggregates over timing and behavioral patterns.

**Storage Requirements:**

- The ABP MUST be encrypted at rest using a key derived from the author's private key material.
- The ABP MUST NOT be shared with verifiers in plaintext. Verification of consistency is performed via zero-knowledge proofs (see Section [future]) that demonstrate the new document's features are consistent with the committed profile without revealing the profile itself.
- The ABP's `author_id` is a pseudonymous identifier. Linking it to a real-world identity requires the author's explicit consent through the World ID integration layer (see Section [future]).

**Profile Portability:**

- Authors MAY export their ABP in an encrypted format for backup or migration.
- The export format includes a version number, the encrypted profile blob, and a verification hash.
- Import requires the author's decryption key and re-verification of the hash.

---

*End of Sections 4 and 5.*

*Section 6 (Cryptographic Commitment and Signing) and Section 7 (Zero-Knowledge Proof Construction) are specified in subsequent documents.*

## 6. Cryptographic Primitives

### 6.1 Notation

The following notation is used throughout this specification. All parties MUST interpret these symbols consistently.

| Symbol | Definition |
|--------|-----------|
| `H(x)` | SHA-256 hash function. Input: arbitrary-length byte string. Output: 256-bit (32-byte) digest. Defined per FIPS 180-4. |
| `H_k(x)` | HMAC-SHA-256 keyed hash. Input: key `k` (byte string), message `x` (byte string). Output: 256-bit MAC. Defined per RFC 2104 with SHA-256 as the underlying hash. |
| `Sign(sk, m)` | Ed25519 signature generation. Input: private key `sk` (32 bytes), message `m` (byte string). Output: signature `sigma` (64 bytes). Defined per RFC 8032, Section 5.1.6. |
| `Verify(pk, m, sigma)` | Ed25519 signature verification. Input: public key `pk` (32 bytes), message `m` (byte string), signature `sigma` (64 bytes). Output: boolean. Defined per RFC 8032, Section 5.1.7. |
| `KDF(seed, info, length)` | HKDF-SHA-256 key derivation. Two-stage extract-then-expand per RFC 5869. Input: input keying material `seed`, context string `info`, desired output length `length` in bytes. Salt: if not specified, defaults to 32 zero bytes. |
| `\|\|` | Byte-string concatenation. `a \|\| b` produces a byte string whose length is `len(a) + len(b)`. |
| `[x]` | Canonical encoding of structured data `x` using deterministic CBOR (RFC 8949, Section 4.2). See Section 6.2.4 for the canonical encoding rules. |
| `{0,1}^n` | The set of all bit strings of length `n`. |
| `x <-$ S` | `x` is sampled uniformly at random from set `S`. |
| `F_i` | Behavioral feature vector for window `i`. See Section 5 for feature definitions. |
| `C_i` | Commitment value at chain position `i`. |
| `sigma` | An Ed25519 signature (64 bytes). |
| `pk`, `sk` | Ed25519 public key (32 bytes) and private key (32 bytes), respectively. |
| `uint64` | Unsigned 64-bit integer, encoded big-endian unless otherwise noted. |
| `bytes32` | A 32-byte (256-bit) value. |

**Byte-string encoding convention:** When a structured value (e.g., a public key, integer, or timestamp) appears as input to a hash function, it MUST first be encoded to a byte string using the canonical CBOR encoding defined in Section 6.2.4, unless an explicit encoding is specified in context.

**Integer encoding within hash inputs:** All integers appearing directly in hash function inputs (outside of CBOR-encoded structures) MUST be encoded as unsigned 64-bit big-endian byte strings (8 bytes), zero-padded on the left.

### 6.2 Hash Functions

#### 6.2.1 Document Hashing

The document hash is computed over a canonical representation of the document content to ensure that semantically identical documents produce identical hashes regardless of superficial formatting differences.

**Canonicalization procedure:**

1. The document content MUST be converted to a Unicode string normalized to NFC form (Unicode Normalization Form C, per UAX #15).
2. All line endings MUST be normalized to U+000A (LINE FEED).
3. Trailing whitespace on each line MUST be removed.
4. Leading and trailing blank lines MUST be removed.
5. The resulting string MUST be encoded as UTF-8.
6. The document hash is: `document_hash = H(utf8_bytes)`.

**Rationale:** NFC normalization prevents equivalent-but-differently-encoded Unicode sequences from producing distinct hashes. Line ending and whitespace normalization prevents platform-dependent formatting from affecting the hash.

#### 6.2.2 Behavioral Data Hashing

Behavioral feature vectors are hashed using SHA-256 over their canonical CBOR encoding:

```
behavior_hash = H(CBOR_encode(F_session))
```

Where `CBOR_encode` follows the deterministic encoding rules in Section 6.2.4, and `F_session` is encoded as a CBOR map with string keys corresponding to feature names and numeric values encoded as follows:

- Integer features: CBOR unsigned or negative integer.
- Floating-point features: CBOR half/single/double float, using the shortest representation that preserves the value exactly. If the value cannot be represented exactly in any IEEE 754 binary floating-point format, it MUST be rounded to the nearest IEEE 754 binary64 (double) value using round-to-nearest-even.

**Window-level behavioral hashing:** For a single window `i`:

```
window_behavior_hash_i = H(CBOR_encode(F_i))
```

#### 6.2.3 Merkle Tree Construction

See Section 6.5 for the complete Merkle tree specification.

#### 6.2.4 Canonical CBOR Encoding

All structures in this protocol that require deterministic encoding MUST use CBOR (RFC 8949) with the following constraints to ensure deterministic output:

1. **Preferred serialization (RFC 8949, Section 4.1):** Integers MUST use the shortest encoding. Simple values MUST use the shortest encoding. Floating-point values MUST use the shortest encoding that preserves the value exactly.
2. **Deterministic map key ordering (RFC 8949, Section 4.2.1):** Map keys MUST be sorted by the byte-wise lexicographic order of their encoded form (shortest encoded key first; among keys of equal encoded length, lexicographic comparison).
3. **No indefinite-length encoding:** All strings, byte strings, arrays, and maps MUST use definite-length encoding.
4. **No duplicate map keys.**
5. **No CBOR tags** unless explicitly required by a structure definition in this specification.
6. **Byte string encoding:** Raw byte values (keys, hashes, nonces) MUST be encoded as CBOR byte strings (major type 2), not as hex-encoded text strings.

Two compliant implementations encoding the same logical structure MUST produce bit-identical CBOR output.

### 6.3 Digital Signatures

#### 6.3.1 Algorithm Selection

This protocol uses Ed25519 (EdDSA over Curve25519) as defined in RFC 8032, Section 5.1, for all digital signature operations.

**Rationale for Ed25519:**

- **Deterministic:** Signature generation does not require a random nonce, eliminating an entire class of implementation vulnerabilities (cf. Sony PS3 ECDSA nonce reuse).
- **Compact:** Public keys are 32 bytes; signatures are 64 bytes.
- **Fast:** Verification is approximately 3x faster than ECDSA-P256 on typical hardware.
- **Well-studied:** Extensive cryptanalytic attention since 2011; no practical attacks known.
- **Resistance to side-channels:** The deterministic nonce derivation uses the private key and message, making timing attacks on nonce generation irrelevant.

#### 6.3.2 Key Generation

Ed25519 key generation proceeds as follows:

1. Sample a 256-bit seed: `seed <-$ {0,1}^256`, using a cryptographically secure pseudorandom number generator (CSPRNG) meeting the requirements of Section 6.3.5.
2. Compute the private scalar and public point per RFC 8032, Section 5.1.5:
   - `h = H(seed)` (SHA-512, per RFC 8032)
   - The lower 32 bytes of `h`, after clamping, form the private scalar `a`.
   - The public key is `pk = [a]B`, where `B` is the Ed25519 base point.
3. The private key `sk` is the 32-byte `seed`. (Note: RFC 8032 defines the private key as the seed, from which the scalar is derived during signing.)
4. The public key `pk` is the 32-byte compressed encoding of the public point.

The seed MUST be stored securely. See Section 7.1 for storage requirements.

#### 6.3.3 Signature Format

An Ed25519 signature `sigma` consists of 64 bytes:

```
sigma = R_encoded || S_encoded
```

Where:
- `R_encoded`: 32 bytes, the compressed Edwards point encoding of `R`.
- `S_encoded`: 32 bytes, the little-endian encoding of scalar `S`.

As defined in RFC 8032, Section 5.1.6.

#### 6.3.4 Signature Generation and Verification

**Signing:**

```
sigma = Sign(sk, m)
```

Where `m` is the message byte string. The implementation MUST follow RFC 8032, Section 5.1.6, exactly. The implementation MUST NOT use any Ed25519 variant (e.g., Ed25519ctx, Ed25519ph) unless explicitly specified.

**Verification:**

```
result = Verify(pk, m, sigma)
```

Returns `true` if and only if the signature is valid per RFC 8032, Section 5.1.7. Implementations MUST reject non-canonical encodings of `S` (i.e., `S >= L`, where `L` is the order of the base point) and MUST perform the cofactored verification equation check.

#### 6.3.5 Random Number Generation Requirements

All random values in this protocol (key seeds, nonces, session identifiers) MUST be generated using a CSPRNG that:

1. Is seeded from an operating-system-provided entropy source (`/dev/urandom` on POSIX, `BCryptGenRandom` on Windows, `getentropy()` where available).
2. Provides at least 256 bits of security against state compromise.
3. Conforms to NIST SP 800-90A (e.g., HMAC-DRBG or CTR-DRBG) or is the operating system's native CSPRNG.

Implementations MUST NOT use userspace PRNGs seeded from timestamps, PIDs, or other low-entropy sources.

### 6.4 Commitment Scheme

#### 6.4.1 Construction

The protocol uses a hash-based commitment scheme for incremental behavioral commitments during writing sessions.

**Commit:**

Given a message `x` (byte string):

1. Sample a 256-bit nonce: `r <-$ {0,1}^256`.
2. Compute the commitment: `c = H(x || r)`.
3. Output `(c, opening)` where `opening = (x, r)`.

**Open:**

Given a commitment `c` and an opening `(x, r)`:

1. Compute `c' = H(x || r)`.
2. Output `valid` if `c' = c`, otherwise `invalid`.

#### 6.4.2 Security Properties

**Hiding (computational):** Given `c = H(x || r)` where `r <-$ {0,1}^256`, no probabilistic polynomial-time adversary can determine any information about `x` with non-negligible advantage, assuming SHA-256 is a random oracle. The 256-bit nonce provides at least 128 bits of security against brute-force search for `x` even when `x` is drawn from a small domain.

**Binding (computational):** No probabilistic polynomial-time adversary can find `(x, r)` and `(x', r')` with `x != x'` such that `H(x || r) = H(x' || r')`, assuming SHA-256 is collision-resistant (birthday bound: 2^128 operations).

#### 6.4.3 Domain Separation

To prevent cross-context commitment collisions, commitment inputs MUST be domain-separated. The message `x` for behavioral window commitments is always a CBOR-encoded structure that includes a `context` field (see Section 8.3.2). This provides implicit domain separation.

### 6.5 Merkle Trees

#### 6.5.1 Construction

The protocol uses a binary Merkle tree over behavioral window commitments. The tree is constructed over an ordered sequence of leaf values `[L_0, L_1, ..., L_{n-1}]`.

**Leaf node computation:**

```
leaf_i = H(0x00 || L_i)
```

The `0x00` prefix byte provides domain separation between leaf and internal nodes (preventing second-preimage attacks on the tree structure).

**Internal node computation:**

For two child nodes `left` and `right`:

```
internal = H(0x01 || left || right)
```

The `0x01` prefix byte distinguishes internal nodes from leaf nodes.

**Tree construction algorithm:**

1. If the input sequence is empty, the Merkle root is defined as `H(0x00)` (hash of a single zero byte).
2. Compute leaf nodes: for each `L_i`, compute `leaf_i = H(0x00 || L_i)`.
3. If the number of leaves is not a power of 2, pad with duplicate copies of the last leaf node until the count is a power of 2. (This is an implementation detail for balanced tree construction; the padding leaves are marked as padding in the proof format.)
4. Iteratively combine pairs of nodes at each level:
   - `node_{level+1, j} = H(0x01 || node_{level, 2j} || node_{level, 2j+1})`
5. The root of the tree is the single node at the highest level.

#### 6.5.2 Proof of Inclusion

A Merkle inclusion proof for leaf `L_i` in a tree with root `R` consists of:

```
MerkleProof {
  leaf_index:  uint64          // 0-based index of the leaf
  leaf_value:  bytes32         // L_i (the raw leaf value, before hashing)
  path:        [PathElement]   // ordered from leaf level to root
  tree_size:   uint64          // number of actual (non-padding) leaves
}

PathElement {
  sibling: bytes32   // the sibling hash at this level
  side:    "left" | "right"  // which side the sibling is on
}
```

**Verification algorithm** for `MerkleProof` against expected root `R`:

```
function VerifyMerkleProof(proof, R):
  current = H(0x00 || proof.leaf_value)
  for each element in proof.path:
    if element.side == "left":
      current = H(0x01 || element.sibling || current)
    else:
      current = H(0x01 || current || element.sibling)
  return current == R
```

The proof length is `ceil(log2(n'))` where `n'` is the number of leaves after padding to a power of 2.

#### 6.5.3 Application in Speakwrite

The Merkle tree is constructed over the sequence of window commitment values:

```
leaves = [C_0, C_1, C_2, ..., C_n]
commitment_root = MerkleRoot(leaves)
```

This allows a prover to demonstrate that a specific window commitment `C_i` is part of the session's commitment chain without revealing the commitment values for other windows. A verifier receiving a selective disclosure of window `i`'s behavioral data can:

1. Verify the commitment opening: `H(F_i || r_i) == C_i` (if standalone commitments are used) or verify the chain link (see Section 8.3.2).
2. Verify the Merkle inclusion proof for `C_i` against the `commitment_root` published in the proof artifact.

### 6.6 Zero-Knowledge Proofs (WorldID Integration)

#### 6.6.1 Semaphore Protocol Overview

WorldID uses the Semaphore protocol to enable zero-knowledge proof of set membership (i.e., "I am a registered unique human") without revealing which specific identity in the set is proving membership.

The Semaphore protocol operates over a Merkle tree of identity commitments. Each registered identity holds:

- `identity_secret`: a private value known only to the identity holder.
- `identity_commitment = H_poseidon(identity_secret)`: published to the on-chain identity set.

The Semaphore identity Merkle tree has all `identity_commitment` values as leaves. The tree root is published on-chain and updated as identities are added.

#### 6.6.2 Groth16 ZK-SNARK Proof System

WorldID's Semaphore circuit is compiled into a Groth16 ZK-SNARK (as described by Groth, 2016). Key properties:

- **Proof size:** Constant: 3 group elements (approximately 128 bytes on BN254).
- **Verification time:** Constant: 3 pairing operations plus a small number of group exponentiations.
- **Trusted setup:** Groth16 requires a per-circuit trusted setup ceremony. WorldID's setup ceremony is conducted by the Worldcoin Foundation. The resulting proving key and verification key are public.
- **Curve:** BN254 (alt_bn128), providing approximately 100 bits of security.
- **Soundness:** Computational soundness under the q-Power Knowledge of Exponent assumption on BN254.

#### 6.6.3 Circuit Inputs

**Public inputs** (visible to the verifier):

| Input | Type | Description |
|-------|------|-------------|
| `merkle_root` | `uint256` | Root of the Semaphore identity Merkle tree at the time of proof generation. |
| `nullifier_hash` | `uint256` | `H_poseidon(identity_secret, external_nullifier)`. Uniquely identifies this identity for this action scope, without revealing the identity. |
| `signal_hash` | `uint256` | `H_poseidon(signal)`. Commits the proof to a specific signal (application-defined payload). |
| `external_nullifier` | `uint256` | `H_poseidon(H_poseidon(action_id), scope)`. Defines the action scope; ensures one proof per identity per scope. |

**Private inputs** (known only to the prover; not revealed):

| Input | Type | Description |
|-------|------|-------------|
| `identity_secret` | `uint256` | The prover's secret identity value. |
| `merkle_path` | `[uint256; depth]` | The sibling hashes along the path from the prover's identity commitment leaf to the Merkle root. |
| `merkle_path_indices` | `[bit; depth]` | The left/right path direction bits corresponding to each level of the Merkle path. |

#### 6.6.4 Circuit Constraints (Informative)

The Semaphore circuit enforces the following constraints:

1. `identity_commitment = H_poseidon(identity_secret)`.
2. The Merkle path from `identity_commitment` using `merkle_path` and `merkle_path_indices` produces `merkle_root`.
3. `nullifier_hash = H_poseidon(identity_secret, external_nullifier)`.
4. `signal_hash = H_poseidon(signal)`.

If all constraints are satisfied, the proof demonstrates: "I know an `identity_secret` whose commitment is in the Merkle tree with root `merkle_root`, and I am committing to `signal` under action scope `external_nullifier`."

#### 6.6.5 Proof Verification

Verification of a WorldID Groth16 proof proceeds as follows:

1. Obtain the verification key `VK` for the Semaphore circuit (published by WorldID / Worldcoin Foundation).
2. Construct the public input vector: `public_inputs = [merkle_root, nullifier_hash, signal_hash, external_nullifier]`.
3. Execute the Groth16 verification equation:
   - Parse the proof as `(A, B, C)` where `A, C` are elements of `G_1` (BN254) and `B` is an element of `G_2` (BN254).
   - Verify: `e(A, B) = e(alpha, beta) * e(sum_i(public_input_i * L_i), gamma) * e(C, delta)`
   - Where `alpha, beta, gamma, delta` are elements of the verification key, `L_i` are the Lagrange basis commitments, and `e` is the BN254 optimal Ate pairing.
4. Verify that `merkle_root` is a known valid root:
   - On-chain: check that `merkle_root` is the current or a recent root of the WorldID identity Merkle tree contract.
   - Off-chain: query the WorldID API endpoint to confirm root validity within an acceptable staleness window (see Section 8.4.2, Step 5).
5. If all checks pass, the proof is valid.

#### 6.6.6 Hash Function Note

The Semaphore/WorldID circuit uses the Poseidon hash function (a SNARK-friendly algebraic hash) internally for Merkle tree construction and nullifier derivation. This is distinct from SHA-256 used elsewhere in this protocol. The two hash functions operate in separate domains:

- **Poseidon:** Used exclusively within the ZK-SNARK circuit (identity commitments, nullifier derivation, signal hashing, and the WorldID identity Merkle tree).
- **SHA-256:** Used for all other protocol operations (document hashing, behavioral data hashing, commitment chains, and the Speakwrite Merkle tree over window commitments).

There is no security dependency between these two hash functions beyond their individual collision resistance and preimage resistance properties.

---

## 7. Key Management

### 7.1 Author Identity Key

#### 7.1.1 Key Generation

The author identity key is a long-lived Ed25519 keypair used to sign all proof artifacts.

**Generation procedure:**

1. Generate a 256-bit seed: `seed <-$ {0,1}^256` using a CSPRNG per Section 6.3.5.
2. Derive the Ed25519 keypair `(sk, pk)` from `seed` per Section 6.3.2.
3. Compute the key fingerprint: `fingerprint = H(pk)` (used as a short identifier).
4. Encrypt and store `seed` per Section 7.1.2.
5. The public key `pk` is not secret and MAY be published freely.

The seed MUST NOT be used for any purpose other than Ed25519 key derivation.

#### 7.1.2 Private Key Storage

The private key seed is encrypted at rest using a key derived from the author's passphrase.

**Encryption procedure:**

1. Generate a 256-bit salt: `salt <-$ {0,1}^256`.
2. Derive an encryption key from the author's passphrase using Argon2id:
   ```
   encryption_key = Argon2id(
     password:    passphrase_utf8,
     salt:        salt,
     memory:      65536,   // 64 MiB
     iterations:  3,       // time cost
     parallelism: 4,       // lanes
     tag_length:  32       // 256-bit output
   )
   ```
   Where `passphrase_utf8` is the UTF-8 encoding of the passphrase, and Argon2id is per RFC 9106.
3. Derive a 256-bit AES key and a 96-bit nonce from `encryption_key`:
   ```
   aes_key  = KDF(encryption_key, "speakwrite-seed-encryption-key", 32)
   aes_nonce = KDF(encryption_key, "speakwrite-seed-encryption-nonce", 12)
   ```
4. Encrypt the seed using AES-256-GCM:
   ```
   ciphertext || auth_tag = AES-256-GCM.Encrypt(aes_key, aes_nonce, seed, aad="")
   ```
   Where the additional authenticated data (AAD) is the empty byte string.
5. Store the encrypted key file:
   ```
   EncryptedKeyFile {
     version:     uint8 = 1
     salt:        bytes32
     argon2_params: {
       memory:      uint32 = 65536
       iterations:  uint32 = 3
       parallelism: uint32 = 4
     }
     ciphertext:  bytes  // 32 bytes (encrypted seed)
     auth_tag:    bytes  // 16 bytes (GCM authentication tag)
   }
   ```

**Decryption procedure:**

1. Read the `EncryptedKeyFile`.
2. Re-derive `encryption_key` from the passphrase and stored salt using the stored Argon2id parameters.
3. Re-derive `aes_key` and `aes_nonce` from `encryption_key`.
4. Decrypt: `seed = AES-256-GCM.Decrypt(aes_key, aes_nonce, ciphertext, auth_tag, aad="")`.
5. If decryption fails (authentication tag mismatch), abort with an error. Do not reveal whether the passphrase or the file is at fault.
6. Derive `(sk, pk)` from `seed` per Section 6.3.2.

**Argon2id parameter rationale:** The chosen parameters (`memory=64 MiB`, `iterations=3`, `parallelism=4`) target approximately 0.5-1.0 seconds of computation on a modern consumer device, providing resistance to brute-force passphrase attacks while remaining usable. Implementations MAY use higher parameters if hardware permits. Implementations MUST NOT use lower parameters.

#### 7.1.3 Backup and Recovery

Authors SHOULD create an offline backup of their private key seed using one of the following methods:

**Method A: Encrypted seed export.**
1. The encrypted key file (Section 7.1.2) MAY be backed up to external storage.
2. The passphrase is required for recovery. Loss of the passphrase renders the backup unrecoverable.

**Method B: BIP-39 mnemonic phrase.**
1. Encode the 256-bit seed as a 24-word BIP-39 mnemonic (per BIP-39 specification).
2. The author MUST write the mnemonic on physical media and store it securely.
3. To recover: convert the mnemonic back to the 256-bit seed and re-derive the keypair.

**Recovery procedure:**
1. Obtain the seed via Method A or Method B.
2. Derive `(sk, pk)` from `seed` per Section 6.3.2.
3. Verify that `pk` matches the expected public key (by comparing fingerprints).
4. Re-encrypt the seed per Section 7.1.2 with a new passphrase and new salt.

**Warning:** If the seed is compromised, the author MUST immediately execute key rotation (Section 7.1.4) and revocation (Section 7.4).

#### 7.1.4 Key Rotation

Key rotation replaces an author's identity keypair while preserving verifiable continuity with their publication history.

**Rotation procedure:**

1. Generate a new keypair `(sk_new, pk_new)` per Section 7.1.1.
2. Construct a key rotation statement:
   ```
   KeyRotationStatement {
     old_pubkey:       Ed25519PublicKey  // pk_old
     new_pubkey:       Ed25519PublicKey  // pk_new
     rotation_time:    uint64           // current Unix timestamp
     reason:           string           // human-readable reason
     statement_hash:   bytes32          // H([old_pubkey, new_pubkey, rotation_time, reason])
   }
   ```
3. Sign the rotation statement with the **old** private key:
   ```
   sigma_old = Sign(sk_old, statement_hash)
   ```
4. Sign the rotation statement with the **new** private key:
   ```
   sigma_new = Sign(sk_new, statement_hash)
   ```
5. Perform WorldID re-binding per Section 7.2 (re-bind step).
6. Publish the signed rotation statement:
   ```
   KeyRotationRecord {
     statement:        KeyRotationStatement
     signature_old:    bytes64   // sigma_old
     signature_new:    bytes64   // sigma_new
     worldid_rebind:   IdentityCertificate  // new identity certificate from re-binding
   }
   ```
7. Revoke the old key per Section 7.4, including the successor pubkey `pk_new`.

**Verification of rotation:** A verifier encountering a rotation record MUST:
1. Verify `sigma_old` over `statement_hash` using `old_pubkey`.
2. Verify `sigma_new` over `statement_hash` using `new_pubkey`.
3. Verify the WorldID re-binding proof in `worldid_rebind`.
4. Verify that the `nullifier_hash` in `worldid_rebind` corresponds to the same WorldID identity as the old identity certificate (i.e., the nullifier for the rebind action matches expectations; see Section 7.2).
5. If all checks pass, accept `new_pubkey` as the successor to `old_pubkey`.

### 7.2 WorldID Binding

#### 7.2.1 Initial Binding

On first use, the author binds their Ed25519 public key to their WorldID identity. This proves that the key is controlled by a unique, verified human.

**Procedure:**

1. Compute the signal: `signal = H(author_pubkey)`.
2. Set the action parameters:
   - `action_id = "app_speakwrite_bind_key"`
   - `scope = ""` (empty; one binding per identity per action)
3. Compute `external_nullifier = H_poseidon(H_poseidon(action_id), scope)`.
4. Initiate WorldID verification (via WorldID SDK or API):
   - The author proves their personhood (orb or device level).
   - The prover generates a Groth16 proof with:
     - Public inputs: `merkle_root`, `nullifier_hash`, `signal_hash = H_poseidon(signal)`, `external_nullifier`
     - Private inputs: `identity_secret`, `merkle_path`, `merkle_path_indices`
5. The WorldID verification returns:
   - `nullifier_hash`: permanently identifies this WorldID identity for this action scope.
   - `merkle_root`: the WorldID identity tree root used.
   - `proof`: the Groth16 proof `(A, B, C)`.
   - `verification_level`: `"orb"` or `"device"`.
6. Construct the identity certificate per Section 7.3.

The `nullifier_hash` is deterministic for a given `(identity_secret, external_nullifier)` pair. This means the same WorldID identity performing the same action always produces the same `nullifier_hash`, enabling linkage of the binding to subsequent publications without revealing the underlying identity.

#### 7.2.2 Re-Binding (Key Rotation)

When rotating keys, the author MUST re-bind the new key to their WorldID identity to maintain continuity.

**Procedure:**

1. Compute the signal: `signal = H(old_pubkey || new_pubkey)`.
2. Set the action parameters:
   - `action_id = "app_speakwrite_rebind_key"`
   - `scope = ""` (empty)
3. Compute `external_nullifier = H_poseidon(H_poseidon(action_id), scope)`.
4. Initiate WorldID verification as in Section 7.2.1, Step 4, using the new signal and action.
5. Receive: `nullifier_hash_rebind`, `merkle_root`, `proof`, `verification_level`.
6. Note: `nullifier_hash_rebind` will differ from the initial binding's `nullifier_hash` because `external_nullifier` is different (different `action_id`). However, both nullifiers are derived from the same `identity_secret`, proving they belong to the same human.
7. Construct a new identity certificate for `new_pubkey` using the rebind proof.

**Cross-action nullifier linkage:** The initial binding and re-binding produce different `nullifier_hash` values because they use different `action_id` values. To verify that a rebinding is performed by the same human as the original binding, the verifier relies on the key rotation statement (Section 7.1.4) signed by both old and new keys, combined with the re-binding's WorldID proof, which guarantees the re-binder is a unique human. A single human cannot produce two distinct valid re-binding proofs (because the `scope` is empty and re-binding is one-per-identity).

### 7.3 Identity Certificate

The identity certificate is the fundamental trust anchor linking an Ed25519 public key to a verified WorldID identity.

**Structure:**

```
IdentityCertificate {
  // Author's Ed25519 public key (32 bytes)
  author_pubkey:        bytes32

  // WorldID nullifier hash for the binding action.
  // Deterministic per (identity, action); serves as a pseudonymous
  // identifier for this author across all publications.
  worldid_nullifier:    bytes32

  // Groth16 ZK-SNARK proof from WorldID verification.
  // Encoded as three BN254 curve points: (A: G1, B: G2, C: G1).
  worldid_proof: {
    a:   [uint256; 2]    // G1 point (x, y)
    b:   [[uint256; 2]; 2]  // G2 point ((x_i, x_r), (y_i, y_r))
    c:   [uint256; 2]    // G1 point (x, y)
  }

  // Root of the WorldID identity Merkle tree at proof generation time.
  worldid_merkle_root:  bytes32

  // WorldID verification level achieved.
  // "orb":    biometric verification via Worldcoin Orb (highest assurance)
  // "device": device-level verification (lower assurance)
  verification_level:   "orb" | "device"

  // The WorldID action identifier used for this binding.
  // For initial binding: "app_speakwrite_bind_key"
  // For re-binding:      "app_speakwrite_rebind_key"
  action_id:            string

  // The signal used in WorldID verification.
  // For initial binding: H(author_pubkey)
  // For re-binding:      H(old_pubkey || new_pubkey)
  signal:               bytes32

  // Unix timestamp (seconds since 1970-01-01T00:00:00Z) of certificate creation.
  created_at:           uint64

  // Unique certificate identifier.
  // Computed as: H(author_pubkey || worldid_nullifier)
  certificate_id:       bytes32
}
```

**Encoding:** The canonical encoding of an `IdentityCertificate` is CBOR per Section 6.2.4, with the following CBOR map key names (string keys, in the order listed above): `"author_pubkey"`, `"worldid_nullifier"`, `"worldid_proof"`, `"worldid_merkle_root"`, `"verification_level"`, `"action_id"`, `"signal"`, `"created_at"`, `"certificate_id"`.

**Self-consistency checks:** Any party receiving an identity certificate MUST verify:
1. `certificate_id == H(author_pubkey || worldid_nullifier)`.
2. `signal == H(author_pubkey)` (for initial binding) or `signal == H(old_pubkey || new_pubkey)` (for re-binding, where `old_pubkey` is obtained from the rotation record).
3. The WorldID proof verifies per Section 6.6.5 with the stated `worldid_merkle_root`, `worldid_nullifier`, signal, and action.
4. `worldid_merkle_root` is a valid (current or recent) WorldID root.
5. `verification_level` is `"orb"` or `"device"`.

**Publication:** The identity certificate SHOULD be published to at least one of:
- A `.well-known/speakwrite/identity.cbor` endpoint on the author's personal domain.
- IPFS, with the CID referenced in the author's proof artifacts.
- A public Speakwrite identity registry (if one exists).

### 7.4 Key Revocation

#### 7.4.1 Revocation Message

An author revokes a key by publishing a signed revocation message.

**Structure:**

```
RevocationMessage {
  // The public key being revoked.
  revoked_pubkey:     bytes32

  // Unix timestamp of revocation.
  revocation_time:    uint64

  // Optional: the successor public key (if rotating).
  // If present, verifiers SHOULD accept publications from this key
  // as continuing the author's identity.
  successor_pubkey:   bytes32 | null

  // Human-readable reason for revocation.
  reason:             string

  // Unique revocation identifier.
  revocation_id:      bytes32  // H(revoked_pubkey || revocation_time)
}
```

**Signing:** The revocation message is signed by the key being revoked:

```
revocation_hash = H(CBOR_encode(RevocationMessage))
sigma_revocation = Sign(sk_revoked, revocation_hash)
```

**Signed revocation record:**

```
SignedRevocation {
  message:    RevocationMessage
  signature:  bytes64   // sigma_revocation
}
```

#### 7.4.2 Revocation Semantics

- A revoked key MUST NOT be accepted for new proof artifacts with a signing timestamp after `revocation_time`.
- Proof artifacts with a signing timestamp before `revocation_time` remain valid (revocation is not retroactive).
- If `successor_pubkey` is present and a valid `KeyRotationRecord` (Section 7.1.4) links `revoked_pubkey` to `successor_pubkey`, verifiers SHOULD treat publications by `successor_pubkey` as from the same author.

#### 7.4.3 Revocation Distribution

Revocation records MUST be made available through the same channels as identity certificates:

- `.well-known/speakwrite/revocations/<revocation_id_hex>.cbor` on the author's domain.
- IPFS, with the CID published alongside the identity certificate.
- A public Speakwrite revocation registry.

**Revocation list format:**

```
RevocationList {
  version:       uint8 = 1
  last_updated:  uint64        // Unix timestamp
  entries:       [SignedRevocation]
}
```

Encoded as CBOR per Section 6.2.4.

#### 7.4.4 Verifier Obligations

Verifiers MUST check for revocations before accepting a proof artifact:

1. Query the author's known publication endpoints for revocation records.
2. If a revocation is found for the signing key:
   a. Verify `sigma_revocation` over the revocation message using `revoked_pubkey`.
   b. Compare the proof artifact's signing timestamp against `revocation_time`.
   c. If the proof artifact was signed **after** `revocation_time`: reject as `INVALID`.
   d. If the proof artifact was signed **before** `revocation_time`: accept (the key was valid at signing time).

Verifiers SHOULD cache revocation records with a maximum staleness of 24 hours.

---

## 8. Protocol Specification

### 8.1 Protocol Phases

The Speakwrite protocol consists of three sequential phases:

| Phase | Name | Actor | Description |
|-------|------|-------|-------------|
| 1 | **Setup** | Author | One-time generation of identity key, WorldID binding, and certificate publication. |
| 2 | **Capture & Sign** | Author | Per-document behavioral capture during writing, session finalization, and proof artifact construction. |
| 3 | **Verify** | Verifier | Validation of a published document's proof artifact against all cryptographic, behavioral, and identity claims. |

Phase 1 is performed once (or upon key rotation). Phase 2 is performed for each document. Phase 3 is performed by any party wishing to verify a document's authenticity.

### 8.2 Phase 1: Author Setup

**Preconditions:** The author has a WorldID identity (orb or device verified).

**Procedure:**

**Step 1: Generate Ed25519 keypair.**
1. Generate `seed <-$ {0,1}^256` per Section 6.3.5.
2. Derive `(sk, pk)` per Section 6.3.2.
3. Compute `fingerprint = H(pk)`.

**Step 2: Encrypt and store private key.**
1. Prompt the author for a passphrase.
2. Encrypt `seed` per Section 7.1.2.
3. Store the `EncryptedKeyFile` in the local key store.

**Step 3: Bind key to WorldID.**
1. Execute the WorldID binding procedure per Section 7.2.1.
2. Construct the `IdentityCertificate` per Section 7.3.
3. Verify the identity certificate's self-consistency checks.

**Step 4: Publish identity certificate.**
1. Publish the `IdentityCertificate` to at least one endpoint (see Section 7.3, Publication).
2. Confirm the certificate is retrievable at the published endpoint.

**Postconditions:** The author possesses `(sk, pk)`, has a stored `EncryptedKeyFile`, and has a published `IdentityCertificate` binding `pk` to their WorldID identity.

### 8.3 Phase 2: Document Capture and Signing

#### 8.3.1 Writing Session Initialization

A writing session begins when the author starts composing a document. The session context tracks all behavioral data and commitments for a single document.

**Procedure:**

1. Generate a session identifier: `session_id <-$ {0,1}^256`.
2. Record the session start time: `timestamp_start = current_unix_timestamp()`.
3. Initialize the behavioral observer (per Section 5) to capture keystroke timing, pause patterns, editing patterns, and other behavioral features.
4. Initialize the commitment chain with the genesis commitment:
   ```
   C_0 = H(CBOR_encode({
     "context":      "speakwrite.commitment.genesis",
     "session_id":   session_id,
     "timestamp":    timestamp_start
   }))
   ```
5. Initialize the window counter: `i = 0`.
6. Initialize the segment-to-window mapping: `segment_map = {}`.
7. Begin capturing behavioral events.

**Session state:**

```
SessionState {
  session_id:       bytes32
  timestamp_start:  uint64
  commitments:      [bytes32]     // [C_0] initially
  window_data:      [WindowData]  // [] initially
  segment_map:      Map<bytes32, [uint64]>  // segment_hash -> [window_indices]
  current_window:   uint64        // 0
  window_start:     uint64        // timestamp_start
}
```

#### 8.3.2 Incremental Commitment During Writing

Every `T` seconds (default: `T = 300`, i.e., 5 minutes), or when the author explicitly triggers a checkpoint, the system generates a new commitment link.

**Procedure for window `i` (where `i >= 1`):**

1. Record the current timestamp: `timestamp_i = current_unix_timestamp()`.
2. Extract the behavioral feature vector for the current window: `F_i` (per Section 5).
3. Generate a 256-bit nonce: `r_i <-$ {0,1}^256`.
4. Compute the window commitment:
   ```
   C_i = H(CBOR_encode({
     "context":      "speakwrite.commitment.window",
     "window_index": i,
     "features":     CBOR_encode(F_i),
     "nonce":        r_i,
     "previous":     C_{i-1},
     "timestamp":    timestamp_i
   }))
   ```
5. Store the window data:
   ```
   WindowData_i {
     window_index:   uint64       // i
     timestamp:      uint64       // timestamp_i
     features:       F_i          // behavioral feature vector
     nonce:          r_i          // commitment nonce
     commitment:     C_i          // the computed commitment
   }
   ```
6. Append `C_i` to the commitment list.
7. Append `WindowData_i` to the window data list.
8. Update the segment-to-window mapping: for each content segment that was modified during this window, add `i` to the list of window indices for that segment's hash.
9. **(Optional) Temporal anchoring:** Submit `C_i` to an external timestamping service (e.g., an RFC 3161 Time-Stamp Authority, a blockchain timestamping service, or OpenTimestamps). Store the returned timestamp receipt.
10. Increment the window counter: `i = i + 1`.

**Hash chain property:** The commitment chain `C_0 -> C_1 -> ... -> C_n` has the property that each `C_i` depends on `C_{i-1}` via inclusion in the hash input. This means:

- Retroactive insertion of a commitment is infeasible (would require finding a SHA-256 preimage).
- Retroactive modification of any `C_j` (for `j < i`) would invalidate all subsequent commitments.
- The chain provides a verifiable temporal ordering of behavioral windows.

**Window duration parameter `T`:** The default value of `T = 300` seconds (5 minutes) balances granularity against overhead. Implementations MAY allow the author to configure `T` within the range `[60, 600]` seconds. The chosen value of `T` MUST be recorded in the session metadata.

#### 8.3.3 Session Finalization

When the author finishes writing and is ready to publish, the session is finalized.

**Procedure:**

1. Perform a final commitment for the last window (if any events have occurred since the last commitment) per Section 8.3.2.
2. Record the session end time: `timestamp_end = current_unix_timestamp()`.
3. Extract the final session-level behavioral feature vector: `F_session` (an aggregate of all window features; see Section 5 for aggregation rules).
4. Compute the behavior hash:
   ```
   behavior_hash = H(CBOR_encode(F_session))
   ```
5. Compute the document hash per Section 6.2.1:
   ```
   document_hash = H(canonical_document_content)
   ```
6. Build the Merkle tree over all window commitments per Section 6.5:
   ```
   commitment_root = MerkleRoot([C_0, C_1, ..., C_n])
   ```
7. Construct the behavioral summary (the subset of session data included in the proof artifact):
   ```
   BehavioralSummary {
     session_id:           bytes32
     timestamp_start:      uint64
     timestamp_end:        uint64
     window_count:         uint64
     window_duration:      uint64        // T, in seconds
     total_keystrokes:     uint64
     total_events:         uint64
     features:             F_session     // session-level aggregate features
     segment_map:          Map<bytes32, [uint64]>  // segment_hash -> window indices
   }
   ```
8. Verify internal consistency:
   - `behavior_hash == H(CBOR_encode(F_session))` (sanity check).
   - The Merkle tree root is correctly computed.
   - All commitment chain links are valid.

#### 8.3.4 Signing

At publish time, the author constructs the proof artifact and signs it.

**Procedure:**

**Step 1: Compute composite signal.**
```
signal = H(document_hash || author_pubkey || behavior_hash || commitment_root)
```

This binds the WorldID proof to the specific document, author, behavioral data, and commitment chain. Any modification to any component invalidates the signal and thus the WorldID proof.

**Step 2: Perform WorldID verification.**
1. Set action parameters:
   - `action_id = "app_speakwrite_publish"`
   - `scope = hex_encode(signal)` (the signal as a hex string)
2. Compute `external_nullifier = H_poseidon(H_poseidon(action_id), scope)`.
3. Invoke WorldID proof generation with:
   - `signal = signal` (as computed in Step 1)
   - `action_id = "app_speakwrite_publish"`
4. Receive from WorldID:
   - `nullifier_hash`: identifies this WorldID identity for this publication action.
   - `merkle_root`: the WorldID identity tree root used.
   - `zk_proof`: the Groth16 proof.
   - `verification_level`: `"orb"` or `"device"`.

**Step 3: Verify nullifier consistency.**
- The `nullifier_hash` returned in Step 2 uses the `"app_speakwrite_publish"` action scope, which differs from the `"app_speakwrite_bind_key"` action scope used in the identity certificate. Therefore, the nullifier values will differ.
- To link the publication to the author's identity certificate, the proof artifact includes both the identity certificate (which contains the binding nullifier) and the publication's WorldID proof (which contains the publication nullifier). Both are produced by the same WorldID identity, as guaranteed by the Semaphore protocol's uniqueness property.
- Verifiers confirm authorship by checking both WorldID proofs and verifying the Ed25519 signature chain.

**Step 4: Construct the proof artifact.**

```
ProofArtifact {
  version:              uint8 = 1
  document_hash:        bytes32
  author_pubkey:        bytes32
  behavior_hash:        bytes32
  commitment_root:      bytes32
  signal:               bytes32
  session_metadata: {
    session_id:         bytes32
    timestamp_start:    uint64
    timestamp_end:      uint64
    window_count:       uint64
    window_duration:    uint64
  }
  behavioral_summary:   BehavioralSummary
  worldid_proof: {
    nullifier_hash:     bytes32
    merkle_root:        bytes32
    proof:              Groth16Proof
    verification_level: "orb" | "device"
    action_id:          string
  }
  identity_certificate_id: bytes32
  commitment_chain:     [bytes32]        // [C_0, ..., C_n] (full chain)
  merkle_tree_depth:    uint8
  timestamp_receipts:   [TimestampReceipt] | null  // optional external timestamps
  segment_map:          Map<bytes32, [uint64]>
  signature:            bytes64          // Ed25519 signature (populated in Step 5)
}
```

**Step 5: Sign the proof artifact.**

1. Encode the proof artifact (with `signature` set to 64 zero bytes as a placeholder) using canonical CBOR per Section 6.2.4.
2. Compute the artifact hash: `artifact_hash = H(CBOR_encode(P))`.
3. Sign: `sigma = Sign(sk, artifact_hash)`.
4. Set `P.signature = sigma`.

**Step 6: Serialize and attach.**

1. Re-encode the proof artifact with the populated signature field.
2. The proof artifact is attached to the document for publication. Attachment methods include:
   - Embedded as a CBOR-encoded blob in the document metadata.
   - Published at a separate URL referenced from the document.
   - Published to IPFS with the CID referenced in the document.

#### 8.3.5 Content-Behavior Entanglement

To prevent an author from substituting AI-generated content for a portion of a document while retaining genuine behavioral data from other portions, the protocol enforces content-behavior entanglement through the `segment_map`.

**Segment definition:**

A segment is a contiguous unit of document content, defined as a paragraph (delimited by double newlines in the canonical content representation). Each segment is identified by its hash:

```
segment_hash = H(canonical_segment_content)
```

Where `canonical_segment_content` is the UTF-8 encoding of the NFC-normalized, whitespace-trimmed paragraph text.

**Mapping construction:**

During writing, the behavioral observer tracks which content segments are modified during each behavioral window. The `segment_map` records, for each segment, the list of window indices during which the segment was created or modified:

```
segment_map: {
  segment_hash_0: [1, 2, 3],       // segment 0 was modified in windows 1, 2, 3
  segment_hash_1: [3, 4],           // segment 1 was modified in windows 3, 4
  segment_hash_2: [5, 6, 7, 8],    // segment 2 was modified in windows 5-8
  ...
}
```

**Verification use:**

A verifier can use the `segment_map` to:

1. Confirm that every segment in the document has at least one associated behavioral window.
2. Confirm that the associated behavioral windows contain plausible typing activity (non-zero keystrokes, reasonable timing distributions) for the length and complexity of the segment.
3. Detect anomalies: a long, complex segment associated with a single short window (suggesting paste-from-external-source) is flagged.
4. Verify Merkle inclusion proofs for the specific windows associated with a segment, without requiring disclosure of all window data.

**Entanglement integrity:** The `segment_map` is included in the `BehavioralSummary`, which is hashed into `behavior_hash`, which is included in the `signal` for the WorldID proof. Therefore, any modification to the `segment_map` invalidates the WorldID proof.

### 8.4 Phase 3: Verification

#### 8.4.1 Verification Inputs

A verifier requires the following inputs:

| Input | Source | Required |
|-------|--------|----------|
| Published document content | The document itself | Yes |
| Proof artifact `P` | Attached to or referenced by the document | Yes |
| Author's identity certificate | Fetched via `P.identity_certificate_id`, author's domain, or a registry | Yes |
| WorldID verification key | Published by the Worldcoin Foundation | Yes (can be cached) |
| Revocation records for `P.author_pubkey` | Author's domain or revocation registry | Yes (absence means no revocation) |
| Previous proof artifacts by same nullifier | Verifier's local database | No (for cross-document consistency) |
| Human behavioral baseline ranges | Defined in Section 5 | Yes (bundled with verifier implementation) |

#### 8.4.2 Verification Steps

The following steps MUST be performed in order. If any step marked as MUST-PASS fails, the verifier MUST halt and return the corresponding failure result.

---

**Step 1: Structural Validation**

1. Parse the proof artifact `P` from its serialized form (CBOR or JSON).
2. Verify that all required fields are present per the schema in Section 8.5.
3. Verify `P.version == 1`. If the version is unrecognized, return `INVALID` with reason `"unsupported_version"`.
4. Verify field type constraints (e.g., `document_hash` is exactly 32 bytes, `window_count >= 1`, `timestamp_start < timestamp_end`).
5. Verify that `P.session_metadata.window_duration` is in the range `[60, 600]`.

**Result on failure:** `INVALID`, reason: `"malformed_proof_artifact"`.

---

**Step 2: Document Integrity** (MUST-PASS)

1. Compute the canonical document hash: `computed_document_hash = H(canonical_document_content)` per Section 6.2.1.
2. Compare `computed_document_hash` with `P.document_hash`.
3. If they do not match: return `TAMPERED`, reason: `"document_hash_mismatch"`.

---

**Step 3: Signature Verification** (MUST-PASS)

1. Extract `author_pubkey` from `P.author_pubkey`.
2. Reconstruct the signed artifact: create a copy of `P` with `P.signature` replaced by 64 zero bytes.
3. Compute `artifact_hash = H(CBOR_encode(P_copy))`.
4. Verify: `Verify(author_pubkey, artifact_hash, P.signature)`.
5. If verification fails: return `INVALID`, reason: `"signature_verification_failed"`.

---

**Step 4: Revocation Check** (MUST-PASS)

1. Query revocation sources for `P.author_pubkey`.
2. If a valid `SignedRevocation` is found:
   a. Verify the revocation signature per Section 7.4.1.
   b. If `P.session_metadata.timestamp_end > revocation_message.revocation_time`: return `INVALID`, reason: `"key_revoked"`.
   c. If `P.session_metadata.timestamp_end <= revocation_message.revocation_time`: proceed (the key was valid at signing time).

---

**Step 5: Identity Certificate Verification** (MUST-PASS)

1. Fetch the identity certificate for `P.author_pubkey` using `P.identity_certificate_id`.
2. Verify the identity certificate's self-consistency per Section 7.3.
3. Verify the identity certificate's WorldID proof:
   a. Reconstruct the public inputs from the certificate's fields.
   b. Execute Groth16 verification per Section 6.6.5.
   c. Verify that `identity_certificate.worldid_merkle_root` is a valid WorldID root (current or within an acceptable staleness window of 7 days).
4. Verify that `identity_certificate.author_pubkey == P.author_pubkey`.
5. If any sub-check fails: return `INVALID`, reason: `"identity_certificate_invalid"`.

---

**Step 6: WorldID Publication Proof Verification** (MUST-PASS)

1. Reconstruct the composite signal:
   ```
   computed_signal = H(P.document_hash || P.author_pubkey || P.behavior_hash || P.commitment_root)
   ```
2. Verify `computed_signal == P.signal`. If not: return `INVALID`, reason: `"signal_mismatch"`.
3. Reconstruct the public inputs for the publication WorldID proof:
   - `merkle_root = P.worldid_proof.merkle_root`
   - `nullifier_hash = P.worldid_proof.nullifier_hash`
   - `signal_hash = H_poseidon(P.signal)`
   - `external_nullifier = H_poseidon(H_poseidon(P.worldid_proof.action_id), hex_encode(P.signal))`
4. Execute Groth16 verification per Section 6.6.5:
   - Verify the proof `P.worldid_proof.proof` against public inputs using the WorldID verification key.
5. Verify that `P.worldid_proof.merkle_root` is a valid WorldID root (current or within an acceptable staleness window of 7 days).
6. Verify that `P.worldid_proof.action_id == "app_speakwrite_publish"`.
7. If any sub-check fails: return `INVALID`, reason: `"worldid_proof_invalid"`.

---

**Step 7: Behavioral Plausibility Assessment**

This step does not produce a hard pass/fail but contributes to the verification level determination.

1. Decode `P.behavioral_summary` and verify:
   ```
   computed_behavior_hash = H(CBOR_encode(P.behavioral_summary.features))
   ```
   If `computed_behavior_hash != P.behavior_hash`: return `INVALID`, reason: `"behavior_hash_mismatch"`.

2. For each behavioral feature `f` in `P.behavioral_summary.features`, check whether `f` falls within the established human baseline range `[baseline_min_f, baseline_max_f]` (defined in Section 5):
   - If `f` is within range: mark as `normal`.
   - If `f` is outside range but within `2x` of the boundary: mark as `atypical`.
   - If `f` is outside `2x` of the boundary: mark as `anomalous`.

3. Compute the plausibility score:
   ```
   plausibility_score = (count_normal) / (count_normal + count_atypical + count_anomalous)
   ```
   Where each count refers to the number of features in that category.

4. Verify segment-level entanglement:
   a. For each segment in the document:
      - Compute `segment_hash = H(canonical_segment_content)`.
      - Look up `P.segment_map[segment_hash]`.
      - If the segment hash is not in `P.segment_map`: flag as `unmapped_segment`.
   b. For each mapped segment, verify that the associated windows have non-trivial behavioral activity:
      - Sum the `total_keystrokes` across the associated windows.
      - Compare against the segment's character count.
      - If the keystroke count is less than 10% of the character count: flag as `low_activity_segment`.

5. Aggregate anomaly flags:
   - `anomaly_count = count_anomalous + count_unmapped_segments + count_low_activity_segments`.
   - If `anomaly_count > 0`: set `behavioral_anomaly = true`.
   - Otherwise: set `behavioral_anomaly = false`.

---

**Step 8: Commitment Chain Integrity Verification**

1. Verify the Merkle tree root:
   - Recompute `computed_commitment_root = MerkleRoot(P.commitment_chain)` per Section 6.5.
   - If `computed_commitment_root != P.commitment_root`: return `INVALID`, reason: `"commitment_root_mismatch"`.

2. Verify chain integrity:
   - Verify that `P.commitment_chain[0]` is a valid genesis commitment:
     ```
     expected_C_0 = H(CBOR_encode({
       "context":      "speakwrite.commitment.genesis",
       "session_id":   P.session_metadata.session_id,
       "timestamp":    P.session_metadata.timestamp_start
     }))
     ```
     If `P.commitment_chain[0] != expected_C_0`: return `INVALID`, reason: `"genesis_commitment_mismatch"`.
   - For `i = 1` to `n`: verify that each `C_i` in the chain depends on `C_{i-1}`. (Note: full verification of interior commitments requires the window data and nonces, which are not always disclosed. If window openings are provided, verify them. If not, the chain structure is verified via the Merkle root and genesis commitment.)

3. Verify temporal ordering:
   - If `P.timestamp_receipts` is non-null:
     - For each `TimestampReceipt` in `P.timestamp_receipts`:
       a. Verify the receipt against the relevant timestamping service (e.g., verify an RFC 3161 timestamp token, or verify a blockchain transaction inclusion).
       b. Verify that the timestamped value matches the corresponding `C_i`.
       c. Verify that the timestamp in the receipt is consistent with the session timeline (i.e., receipt timestamps are non-decreasing and fall within the session's `[timestamp_start, timestamp_end]` range, with a tolerance of 60 seconds for clock skew).
     - If any receipt verification fails: flag `timestamp_anomaly = true` but do not reject (timestamps are supplementary evidence).

4. Verify `P.commitment_chain` length consistency:
   - `len(P.commitment_chain)` MUST equal `P.session_metadata.window_count + 1` (window count plus genesis).

---

**Step 9: Cross-Document Consistency (Optional)**

This step is performed only if the verifier has access to previous proof artifacts from the same author (identified by the same WorldID publication nullifier pattern or the same `author_pubkey`).

1. Retrieve previous proof artifacts for the same author.
2. For each previous proof artifact `P_prev`:
   a. Extract `P_prev.behavioral_summary.features`.
   b. Compute a feature-wise distance metric between `P.behavioral_summary.features` and `P_prev.behavioral_summary.features`:
      ```
      For each feature f:
        delta_f = |P.features[f] - P_prev.features[f]| / baseline_stddev_f
      consistency_score = 1.0 - (mean(delta_f for all f) / max_expected_delta)
      ```
      Where `baseline_stddev_f` is the standard deviation for feature `f` across the human population (defined in Section 5), and `max_expected_delta` is a configurable threshold (default: 3.0 standard deviations).
   c. Clamp `consistency_score` to `[0.0, 1.0]`.
3. Compute the aggregate consistency score as the mean of pairwise consistency scores.
4. If `consistency_score < 0.5`: flag `consistency_anomaly = true`.

#### 8.4.3 Verification Levels

Based on the results of Steps 1-9, the verifier assigns one of the following verification outcomes.

**Formal outcome definitions:**

| Outcome | Code | Conditions |
|---------|------|------------|
| `VERIFIED_STRONG` | `0x01` | Steps 1-8 all pass. `P.worldid_proof.verification_level == "orb"`. `behavioral_anomaly == false`. Cross-document consistency available and `consistency_score >= 0.7`. |
| `VERIFIED_MODERATE` | `0x02` | Steps 1-8 all pass. Either: `verification_level == "device"`, OR cross-document history is unavailable, OR `0.5 <= consistency_score < 0.7`. `behavioral_anomaly == false`. |
| `VERIFIED_WEAK` | `0x03` | Steps 1-3 and Step 7 pass (signature and behavioral data are valid). WorldID proof is absent or cannot be verified (e.g., stale Merkle root beyond the acceptance window). `behavioral_anomaly == false`. |
| `BEHAVIORAL_ANOMALY` | `0x04` | Steps 1-6 and Step 8 pass (all cryptographic checks succeed). `behavioral_anomaly == true` (Step 7 flagged anomalies). |
| `INVALID` | `0x05` | Any MUST-PASS step (Steps 2, 3, 4, 5, 6) fails, or a structural/commitment integrity check fails. The specific failing step and reason are included in the result. |
| `TAMPERED` | `0x06` | Step 2 fails specifically: `document_hash` does not match the document content. This is a special case of `INVALID` indicating the document has been modified after signing. |

**Outcome structure:**

```
VerificationResult {
  outcome:              uint8            // outcome code
  outcome_label:        string           // e.g., "VERIFIED_STRONG"
  document_hash:        bytes32          // the computed document hash
  author_pubkey:        bytes32          // from the proof artifact
  verification_level:   "orb" | "device" | null
  plausibility_score:   float64          // from Step 7
  consistency_score:    float64 | null   // from Step 9, if available
  anomaly_flags:        [string]         // list of anomaly descriptions
  failed_step:          uint8 | null     // step number that failed, if applicable
  failure_reason:       string | null    // reason for failure, if applicable
  verified_at:          uint64           // Unix timestamp of verification
}
```

### 8.5 Proof Artifact Schema

The following is the complete, formal schema for the proof artifact. Implementations MUST serialize and deserialize proof artifacts conforming to this schema. The schema is presented in a JSON Schema-like notation for clarity, but the canonical wire format is CBOR per Section 6.2.4.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://speakwrite.org/schemas/proof-artifact/v1",
  "title": "Speakwrite Proof Artifact v1",
  "description": "Cryptographic proof of human authorship for a document, binding keystroke behavioral analysis, author identity, and WorldID personhood verification.",
  "type": "object",
  "required": [
    "version",
    "document_hash",
    "author_pubkey",
    "behavior_hash",
    "commitment_root",
    "signal",
    "session_metadata",
    "behavioral_summary",
    "worldid_proof",
    "identity_certificate_id",
    "commitment_chain",
    "merkle_tree_depth",
    "segment_map",
    "signature"
  ],
  "additionalProperties": false,
  "properties": {

    "version": {
      "type": "integer",
      "const": 1,
      "description": "Protocol version. MUST be 1 for this specification."
    },

    "document_hash": {
      "type": "string",
      "format": "byte32-hex",
      "pattern": "^[0-9a-f]{64}$",
      "description": "SHA-256 hash of the canonical document content (Section 6.2.1). 32 bytes, hex-encoded in JSON; raw bytes in CBOR."
    },

    "author_pubkey": {
      "type": "string",
      "format": "byte32-hex",
      "pattern": "^[0-9a-f]{64}$",
      "description": "Ed25519 public key of the author. 32 bytes."
    },

    "behavior_hash": {
      "type": "string",
      "format": "byte32-hex",
      "pattern": "^[0-9a-f]{64}$",
      "description": "SHA-256 hash of the CBOR-encoded session-level behavioral feature vector (Section 6.2.2). 32 bytes."
    },

    "commitment_root": {
      "type": "string",
      "format": "byte32-hex",
      "pattern": "^[0-9a-f]{64}$",
      "description": "Root of the Merkle tree over commitment chain values [C_0, ..., C_n] (Section 6.5). 32 bytes."
    },

    "signal": {
      "type": "string",
      "format": "byte32-hex",
      "pattern": "^[0-9a-f]{64}$",
      "description": "Composite signal: H(document_hash || author_pubkey || behavior_hash || commitment_root). 32 bytes. Used as the WorldID signal input."
    },

    "session_metadata": {
      "type": "object",
      "required": [
        "session_id",
        "timestamp_start",
        "timestamp_end",
        "window_count",
        "window_duration"
      ],
      "additionalProperties": false,
      "properties": {
        "session_id": {
          "type": "string",
          "format": "byte32-hex",
          "pattern": "^[0-9a-f]{64}$",
          "description": "Randomly generated 256-bit session identifier."
        },
        "timestamp_start": {
          "type": "integer",
          "minimum": 0,
          "description": "Unix timestamp (seconds) when the writing session began."
        },
        "timestamp_end": {
          "type": "integer",
          "minimum": 0,
          "description": "Unix timestamp (seconds) when the writing session ended. MUST be > timestamp_start."
        },
        "window_count": {
          "type": "integer",
          "minimum": 1,
          "description": "Number of behavioral windows captured (excluding the genesis commitment). MUST equal len(commitment_chain) - 1."
        },
        "window_duration": {
          "type": "integer",
          "minimum": 60,
          "maximum": 600,
          "description": "Duration of each behavioral window in seconds. Default: 300."
        }
      }
    },

    "behavioral_summary": {
      "type": "object",
      "required": [
        "session_id",
        "timestamp_start",
        "timestamp_end",
        "window_count",
        "window_duration",
        "total_keystrokes",
        "total_events",
        "features",
        "segment_map"
      ],
      "additionalProperties": false,
      "properties": {
        "session_id": {
          "type": "string",
          "format": "byte32-hex",
          "description": "MUST match session_metadata.session_id."
        },
        "timestamp_start": {
          "type": "integer",
          "minimum": 0,
          "description": "MUST match session_metadata.timestamp_start."
        },
        "timestamp_end": {
          "type": "integer",
          "minimum": 0,
          "description": "MUST match session_metadata.timestamp_end."
        },
        "window_count": {
          "type": "integer",
          "minimum": 1,
          "description": "MUST match session_metadata.window_count."
        },
        "window_duration": {
          "type": "integer",
          "minimum": 60,
          "maximum": 600,
          "description": "MUST match session_metadata.window_duration."
        },
        "total_keystrokes": {
          "type": "integer",
          "minimum": 0,
          "description": "Total number of keystroke events recorded across all windows."
        },
        "total_events": {
          "type": "integer",
          "minimum": 0,
          "description": "Total number of all behavioral events (keystrokes, mouse events, pauses, etc.) across all windows."
        },
        "features": {
          "type": "object",
          "description": "Session-level aggregate behavioral feature vector. Keys are feature names (strings); values are numeric (integer or float). The exact feature set is defined in Section 5. This object is CBOR-encoded and hashed to produce behavior_hash.",
          "additionalProperties": {
            "type": "number"
          }
        },
        "segment_map": {
          "type": "object",
          "description": "Mapping from segment hashes (hex-encoded bytes32) to arrays of window indices. Every segment in the document SHOULD have an entry.",
          "additionalProperties": {
            "type": "array",
            "items": {
              "type": "integer",
              "minimum": 0
            },
            "minItems": 1
          }
        }
      }
    },

    "worldid_proof": {
      "type": "object",
      "required": [
        "nullifier_hash",
        "merkle_root",
        "proof",
        "verification_level",
        "action_id"
      ],
      "additionalProperties": false,
      "properties": {
        "nullifier_hash": {
          "type": "string",
          "format": "byte32-hex",
          "pattern": "^[0-9a-f]{64}$",
          "description": "WorldID nullifier hash for this publication action. Uniquely identifies this WorldID identity for this action scope."
        },
        "merkle_root": {
          "type": "string",
          "format": "byte32-hex",
          "pattern": "^[0-9a-f]{64}$",
          "description": "Root of the WorldID identity Merkle tree at proof generation time."
        },
        "proof": {
          "type": "object",
          "required": ["a", "b", "c"],
          "additionalProperties": false,
          "description": "Groth16 ZK-SNARK proof encoded as BN254 curve points.",
          "properties": {
            "a": {
              "type": "array",
              "items": { "type": "string", "pattern": "^0x[0-9a-f]{1,64}$" },
              "minItems": 2,
              "maxItems": 2,
              "description": "G1 point [x, y] as hex-encoded uint256 values."
            },
            "b": {
              "type": "array",
              "items": {
                "type": "array",
                "items": { "type": "string", "pattern": "^0x[0-9a-f]{1,64}$" },
                "minItems": 2,
                "maxItems": 2
              },
              "minItems": 2,
              "maxItems": 2,
              "description": "G2 point [[x_imag, x_real], [y_imag, y_real]] as hex-encoded uint256 values."
            },
            "c": {
              "type": "array",
              "items": { "type": "string", "pattern": "^0x[0-9a-f]{1,64}$" },
              "minItems": 2,
              "maxItems": 2,
              "description": "G1 point [x, y] as hex-encoded uint256 values."
            }
          }
        },
        "verification_level": {
          "type": "string",
          "enum": ["orb", "device"],
          "description": "The WorldID verification level achieved. 'orb' indicates biometric verification; 'device' indicates device-level verification."
        },
        "action_id": {
          "type": "string",
          "const": "app_speakwrite_publish",
          "description": "The WorldID action identifier. MUST be 'app_speakwrite_publish' for publication proofs."
        }
      }
    },

    "identity_certificate_id": {
      "type": "string",
      "format": "byte32-hex",
      "pattern": "^[0-9a-f]{64}$",
      "description": "The certificate_id (H(author_pubkey || worldid_nullifier)) of the author's identity certificate. Used to fetch the certificate for verification."
    },

    "commitment_chain": {
      "type": "array",
      "items": {
        "type": "string",
        "format": "byte32-hex",
        "pattern": "^[0-9a-f]{64}$"
      },
      "minItems": 2,
      "description": "The complete commitment chain [C_0, C_1, ..., C_n]. C_0 is the genesis commitment. Length MUST be session_metadata.window_count + 1. Each entry is 32 bytes."
    },

    "merkle_tree_depth": {
      "type": "integer",
      "minimum": 1,
      "maximum": 32,
      "description": "Depth of the Merkle tree constructed over the commitment chain. Equal to ceil(log2(len(commitment_chain))) after padding to power-of-2."
    },

    "timestamp_receipts": {
      "type": ["array", "null"],
      "items": {
        "type": "object",
        "required": [
          "window_index",
          "commitment_value",
          "receipt_type",
          "receipt_data",
          "receipt_timestamp"
        ],
        "additionalProperties": false,
        "properties": {
          "window_index": {
            "type": "integer",
            "minimum": 0,
            "description": "Index of the commitment in the chain that was timestamped."
          },
          "commitment_value": {
            "type": "string",
            "format": "byte32-hex",
            "pattern": "^[0-9a-f]{64}$",
            "description": "The commitment value that was submitted for timestamping. MUST match commitment_chain[window_index]."
          },
          "receipt_type": {
            "type": "string",
            "enum": ["rfc3161", "opentimestamps", "blockchain_tx"],
            "description": "Type of timestamp receipt."
          },
          "receipt_data": {
            "type": "string",
            "contentEncoding": "base64",
            "description": "The raw timestamp receipt/proof, base64-encoded. Format depends on receipt_type: RFC 3161 TimeStampResp (DER), OpenTimestamps proof, or blockchain transaction proof."
          },
          "receipt_timestamp": {
            "type": "integer",
            "minimum": 0,
            "description": "Unix timestamp (seconds) from the timestamping service. Used for temporal ordering verification."
          }
        }
      },
      "description": "Optional array of external timestamp receipts for commitment chain values. Provides independent temporal anchoring."
    },

    "segment_map": {
      "type": "object",
      "description": "Top-level copy of segment_map for ease of access. MUST be identical to behavioral_summary.segment_map. Maps segment hashes to arrays of window indices.",
      "additionalProperties": {
        "type": "array",
        "items": {
          "type": "integer",
          "minimum": 0
        },
        "minItems": 1
      }
    },

    "signature": {
      "type": "string",
      "format": "byte64-hex",
      "pattern": "^[0-9a-f]{128}$",
      "description": "Ed25519 signature over H(CBOR_encode(P)), where P is this proof artifact with the signature field set to 64 zero bytes. 64 bytes."
    }
  }
}
```

**CBOR wire format notes:**

- In CBOR encoding, all `byte32-hex` and `byte64-hex` fields are encoded as CBOR byte strings (major type 2), not as hex text strings. The hex encoding is used only in JSON representations.
- The `proof.a`, `proof.b`, `proof.c` fields in CBOR are encoded as arrays of CBOR byte strings (each uint256 as a 32-byte big-endian byte string).
- The `features` map keys in CBOR are text strings; values are CBOR numbers (integer or floating-point per Section 6.2.2).
- Map key ordering in CBOR follows the deterministic rules in Section 6.2.4.

**Proof artifact size estimate:** A typical proof artifact for a 30-minute writing session (6 windows) is approximately 1.5-3 KB in CBOR encoding, depending on the number of features and segments. The dominant cost is the commitment chain and behavioral features.

---

*End of Sections 6, 7, and 8.*

## 9. Embeddable Verification Widget

### 9.1 Overview

The Speakwrite verification widget is a self-contained web component (`<human-verified>`) that content publishers embed alongside their posts. It fetches the proof artifact associated with a document, performs full client-side verification, and renders a trust badge with expandable detail panel. Because all verification logic executes on the reader's device, the widget operates under a zero-trust model: neither the hosting page nor the proof-serving infrastructure is trusted beyond data transport.

The widget is distributed as a single JavaScript module (~45 KB gzipped) with no external runtime dependencies. Verification cryptography is handled by embedded libsodium (compiled to WebAssembly). The widget registers the `<human-verified>` custom element on first import and is compatible with any HTML page regardless of frontend framework.

### 9.2 Widget Interface

#### 9.2.1 HTML Element Declaration

```html
<human-verified
  proof-url="/proofs/my-post.json"
  document-selector="#article-content"
  identity-registry="https://registry.speakwrite.org"
  theme="auto"
  locale="en"
  compact="false"
  cache-ttl="3600"
  sandbox-mode="worker"
  verification-timeout="15000"
  show-details="expandable"
  badge-position="inline"
></human-verified>
```

#### 9.2.2 Attribute Specification

| Attribute | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `proof-url` | `string` (URL) | -- | Yes | Absolute or relative URL to the proof artifact JSON file. Resolved relative to the hosting page's `<base>` or origin. Must serve `application/json` or `application/cbor` with appropriate CORS headers. |
| `document-selector` | `string` (CSS selector) | `"article"` | No | CSS selector identifying the DOM element whose text content should be hashed and compared against the proof's `document_hash`. The widget extracts canonical text from this element (see Section 9.3.2). |
| `identity-registry` | `string` (URL) | `null` | No | Base URL of an identity registry service (Section 10.2). When provided, the widget fetches author metadata (display name, avatar, publication count) for the detail panel. When `null`, the widget displays only the nullifier-derived author ID. |
| `theme` | `"light"` \| `"dark"` \| `"auto"` | `"auto"` | No | Visual theme. `"auto"` reads `prefers-color-scheme` from the user agent and observes changes. `"light"` and `"dark"` force a fixed palette. |
| `locale` | `string` (BCP 47 language tag) | `"en"` | No | Localization of all user-facing strings. Supported locales: `en`, `es`, `fr`, `de`, `ja`, `zh-Hans`, `pt`, `ko`. Falls back to `en` for unsupported tags. |
| `compact` | `"true"` \| `"false"` | `"false"` | No | When `"true"`, renders only the badge icon and verification level without the author pseudonym line. The expandable detail panel remains accessible on interaction. |
| `cache-ttl` | `string` (integer seconds) | `"3600"` | No | Duration in seconds to cache the fetched proof artifact and registry metadata in `sessionStorage`. Set to `"0"` to disable caching. |
| `sandbox-mode` | `"worker"` \| `"iframe"` \| `"inline"` | `"worker"` | No | Isolation strategy for verification logic (see Section 9.5.2). `"worker"` runs in a dedicated Web Worker. `"iframe"` runs in a sandboxed `<iframe>` with no permissions. `"inline"` runs in the main thread (not recommended; no isolation from hosting page JavaScript). |
| `verification-timeout` | `string` (integer ms) | `"15000"` | No | Maximum time in milliseconds to wait for proof fetch and verification to complete before displaying a timeout error state. |
| `show-details` | `"expandable"` \| `"always"` \| `"none"` | `"expandable"` | No | Controls the detail panel. `"expandable"` shows it on user click/enter. `"always"` renders details inline below the badge. `"none"` suppresses the detail panel entirely. |
| `badge-position` | `"inline"` \| `"fixed-bottom-right"` \| `"fixed-bottom-left"` | `"inline"` | No | Rendering position. `"inline"` places the widget in the normal document flow at its insertion point. The `"fixed-*"` options float the badge in a viewport-anchored position. |

#### 9.2.3 JavaScript API

The widget exposes a programmatic interface for applications that need to drive verification imperatively or subscribe to results:

```typescript
interface HumanVerifiedElement extends HTMLElement {
  // Read-only computed state
  readonly verificationState: VerificationState;
  readonly proofArtifact: ProofArtifact | null;
  readonly authorId: string | null;

  // Imperative control
  verify(): Promise<VerificationResult>;
  reset(): void;

  // Events
  addEventListener(type: "verification-complete", listener: (e: CustomEvent<VerificationResult>) => void): void;
  addEventListener(type: "verification-error", listener: (e: CustomEvent<VerificationError>) => void): void;
}

type VerificationState =
  | "idle"
  | "loading"
  | "verified-strong"
  | "verified-moderate"
  | "verified-weak"
  | "anomaly"
  | "invalid"
  | "error";
```

The `verify()` method can be called to programmatically trigger re-verification (e.g., after a single-page navigation updates the document content). It resolves with the full `VerificationResult` object or rejects with a `VerificationError`.

#### 9.2.4 Script Loading

```html
<!-- Preferred: ES module with SRI -->
<script
  type="module"
  src="https://cdn.speakwrite.org/widget/v1/human-verified.js"
  integrity="sha384-{hash}"
  crossorigin="anonymous"
></script>

<!-- Alternative: self-hosted -->
<script type="module" src="/assets/human-verified.js"></script>
```

The module self-registers the `<human-verified>` custom element. If the element is already in the DOM when the script loads, the widget triggers verification automatically. If the element is inserted later (e.g., in a single-page application), the `connectedCallback` lifecycle hook triggers verification on attachment.

### 9.3 Client-Side Verification Flow

When the widget's `connectedCallback` fires (or `verify()` is called), it executes the following steps inside the configured sandbox (Section 9.5.2):

#### 9.3.1 Step 1 -- Fetch Proof Artifact

1. Resolve `proof-url` to an absolute URL relative to the hosting page.
2. Issue a `fetch()` request with `mode: "cors"`, `credentials: "omit"`, and `cache: "default"`.
3. If the response `Content-Type` is `application/cbor`, decode using the embedded CBOR decoder. If `application/json`, parse as JSON.
4. Validate the proof artifact against the Speakwrite proof schema (Section 7). If schema validation fails, enter the `invalid` state with error code `INVALID_PROOF_SCHEMA`.
5. Store the parsed proof in the cache (keyed by `proof-url`) if `cache-ttl > 0`.

#### 9.3.2 Step 2 -- Extract Canonical Document Text

1. Select the DOM element matching `document-selector`. If no element matches, enter the `error` state with error code `SELECTOR_NOT_FOUND`.
2. Read the element's `innerText` property (not `innerHTML` or `textContent`). `innerText` is preferred because it respects CSS rendering: hidden elements are excluded, `<br>` produces newlines, and display layout is approximated. This matches the text a human reader perceives.
3. Apply canonical normalization:
   a. Replace all Unicode line-break characters (U+000A, U+000D, U+000D U+000A, U+2028, U+2029) with a single U+000A (LF).
   b. Collapse all runs of consecutive whitespace characters (spaces, tabs, non-breaking spaces U+00A0) within a single line into a single U+0020 (space).
   c. Strip leading and trailing whitespace from each line.
   d. Strip leading and trailing blank lines from the entire text.
   e. Ensure the text ends with exactly one trailing LF.
4. Encode the normalized text as UTF-8 bytes.

This produces the **canonical document bytes**.

#### 9.3.3 Step 3 -- Compute Document Hash

1. Compute `SHA-256(canonical_document_bytes)`.
2. Encode as lowercase hexadecimal. This is the `computed_document_hash`.

#### 9.3.4 Step 4 -- Compare Document Hash

1. Read `proof.content_snapshot.document_hash` from the proof artifact.
2. Compare `computed_document_hash` to the proof value using constant-time string comparison. If they do not match, enter the `invalid` state with error code `DOCUMENT_HASH_MISMATCH`. This means the document content has been modified since the proof was generated, or the widget is pointed at the wrong content element.

#### 9.3.5 Step 5 -- Verify Cryptographic Signature

Execute the signature verification procedure defined in Section 8.4.1:

1. Reconstruct the signed payload by canonical CBOR re-encoding of the proof artifact's `behavioral_summary`, `content_snapshot`, `worldid_proof`, `key_binding`, and `metadata` fields (in that order, using deterministic CBOR map key ordering per RFC 8949 Section 4.2.1).
2. Extract the `signature` (Ed25519, 64 bytes) and the `public_key` from the proof.
3. Verify `Ed25519_Verify(public_key, signed_payload_bytes, signature)`. If verification fails, enter `invalid` with error code `SIGNATURE_INVALID`.

#### 9.3.6 Step 6 -- Verify Key Binding

Execute the key binding verification procedure defined in Section 8.4.2:

1. Read the key binding object from `proof.key_binding`.
2. Extract the `key_binding.worldid_proof` (the World ID ZKP that was generated at key-bind time).
3. Verify the World ID proof:
   a. Reconstruct the expected `signal` as `H(public_key)`.
   b. The `action_id` must equal `"bind_key"`.
   c. Verify the Groth16 ZKP against the World ID verification key. This uses the embedded verifier (Section 8.4.2) or, if `identity-registry` is provided, queries the on-chain verifier contract.
4. Confirm `key_binding.public_key` matches the `public_key` used in Step 5.
5. If any check fails, enter `invalid` with error code `KEY_BINDING_INVALID`.

#### 9.3.7 Step 7 -- Verify World ID Publication Proof

Execute the World ID publication verification procedure defined in Section 8.4.3:

1. Read `proof.worldid_proof`.
2. The `signal` must equal `H(document_hash ∥ content_snapshot.published_at)`.
3. The `action_id` must equal `"publish"`.
4. The `nullifier_hash` is the author's pseudonymous identifier for this application scope.
5. Verify the Groth16 ZKP.
6. Confirm the `nullifier_hash` matches the nullifier in `key_binding.worldid_proof` (same human authored and published). If they differ, enter `invalid` with error code `NULLIFIER_MISMATCH`.
7. Check `verification_level`: `"orb"` or `"device"`.

#### 9.3.8 Step 8 -- Evaluate Behavioral Plausibility

Evaluate the behavioral summary against human baseline ranges (Section 8.4.4):

1. Check that `behavioral_summary.plausibility_score >= 0.5` (the minimum threshold for a passing result).
2. Check that `behavioral_summary.session_duration_seconds > 0` and is plausible for the document length.
3. If any behavioral metric is flagged as anomalous in `behavioral_summary.anomaly_flags`, record it for the detail panel.

#### 9.3.9 Step 9 -- Fetch Cross-Document History (Optional)

If `identity-registry` is provided:

1. Query the registry for the author's publication history by `author_id` (derived from nullifier, Section 10.1).
2. Retrieve the `cross_document_consistency_score` and `publication_count`.
3. These values enhance the detail panel but do not change the pass/fail determination.

#### 9.3.10 Step 10 -- Determine Verification Level

Assign a verification level using the following precedence rules:

| Level | Criteria |
|-------|----------|
| `verified-strong` | All checks pass AND `verification_level == "orb"` AND `cross_document_consistency_score >= 0.7` (or no registry configured, in which case history requirement is waived on first publication). |
| `verified-moderate` | All checks pass AND (`verification_level == "device"` OR `cross_document_consistency_score < 0.7`). |
| `verified-weak` | All cryptographic checks pass BUT World ID proof is absent or could not be verified (degraded mode). Behavioral analysis passed. |
| `anomaly` | All checks pass BUT one or more `anomaly_flags` are set in the behavioral summary. |
| `invalid` | Any cryptographic verification step failed. |

#### 9.3.11 Step 11 -- Render Result

Dispatch a `verification-complete` CustomEvent with the full `VerificationResult`, then render the badge and (if applicable) detail panel. See Section 9.4.

### 9.4 Verification Result Display

#### 9.4.1 Badge States

The badge is a horizontally-oriented status indicator rendered within the widget's Shadow DOM. Each state has a distinct visual treatment:

**Loading**
- Icon: animated spinner (CSS animation, no GIF dependency).
- Color: neutral gray (`#6B7280` light / `#9CA3AF` dark).
- Label: "Verifying...".
- Behavior: non-interactive during load. The spinner pauses at the timeout threshold if verification has not completed.

**Verified Strong**
- Icon: filled shield with checkmark.
- Color: green (`#059669` light / `#34D399` dark).
- Label: "Human Verified".
- Subtext: "Orb-verified author" (if compact is false).

**Verified Moderate**
- Icon: outlined shield with checkmark.
- Color: blue (`#2563EB` light / `#60A5FA` dark).
- Label: "Human Verified".
- Subtext: "Device-verified author" or "Limited history" (as applicable).

**Verified Weak**
- Icon: outlined shield without checkmark, question mark instead.
- Color: gray (`#6B7280` light / `#9CA3AF` dark).
- Label: "Behavioral Match".
- Subtext: "No identity verification".

**Anomaly**
- Icon: shield with exclamation mark.
- Color: yellow/amber (`#D97706` light / `#FBBF24` dark).
- Label: "Verified with Anomalies".
- Subtext: "Some behavioral patterns flagged".

**Invalid**
- Icon: shield with X mark.
- Color: red (`#DC2626` light / `#F87171` dark).
- Label: "Verification Failed".
- Subtext: human-readable error reason (e.g., "Document has been modified", "Invalid signature", "Key binding check failed").

**Error (Network/Timeout)**
- Icon: cloud with X mark.
- Color: neutral gray.
- Label: "Verification Unavailable".
- Subtext: "Could not fetch proof" or "Verification timed out". Includes a "Retry" button.

#### 9.4.2 Expandable Detail Panel

When the badge is clicked (or activated via keyboard), the detail panel slides open below the badge. The panel contains the following fields, rendered as a definition list:

| Field | Source | Format |
|-------|--------|--------|
| Author Pseudonym | `author_id` derived from nullifier (Section 10.1) | `human_7Kx9mPqR3...` (truncated to 16 characters with full value in tooltip) |
| Display Name | Registry lookup (if available) | Free text or "Anonymous" |
| Verification Level | World ID `verification_level` | "Orb-verified" / "Device-verified" / "Behavioral only" |
| Writing Session Duration | `behavioral_summary.session_duration_seconds` | Human-readable (e.g., "2 hours 14 minutes") |
| Total Keystrokes | `behavioral_summary.total_keystrokes` | Formatted integer (e.g., "12,847") |
| Revision Rate | `behavioral_summary.revision_rate` | Percentage (e.g., "23.4%") |
| Behavioral Plausibility Score | `behavioral_summary.plausibility_score` | 0.0--1.0 with colored bar |
| Anomaly Flags | `behavioral_summary.anomaly_flags` | List of flag names, or "None" |
| Publication Count | Registry lookup | Integer or "Unknown" |
| Cross-Document Consistency | Registry lookup | 0.0--1.0 with colored bar, or "N/A" |
| Signed At | `metadata.signed_at` | ISO 8601 rendered in local timezone |
| Published At | `content_snapshot.published_at` | ISO 8601 rendered in local timezone |
| Proof Artifact | `proof-url` | Clickable link: "View raw proof (JSON)" |
| Verification Code | Widget source | Clickable link: "View verification source" (points to the open-source repository tag matching the widget version) |

#### 9.4.3 Badge Rendering

The badge and detail panel are rendered entirely within a Shadow DOM to isolate styles from the hosting page. All CSS is inlined within the Shadow DOM (no external stylesheets). The widget uses no external fonts; system font stacks only (`system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`).

The badge target dimensions are `min-width: 240px; height: 40px` for the inline variant. The detail panel has `max-width: 480px` and scrolls vertically if content exceeds `400px` height.

### 9.5 Security Considerations for the Widget

#### 9.5.1 Code Integrity

The widget JavaScript module MUST be loaded with Subresource Integrity (SRI):

```html
<script
  type="module"
  src="https://cdn.speakwrite.org/widget/v1/human-verified.js"
  integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC"
  crossorigin="anonymous"
></script>
```

Each release of the widget is published with its SHA-384 hash in the release notes and signed with the project's release signing key. Site operators MUST pin the SRI hash in their templates.

If the widget is self-hosted, the site operator takes responsibility for integrity. The recommended deployment is to vendor the exact version and compute the SRI hash from their own copy.

#### 9.5.2 Execution Sandbox

Because the hosting page's JavaScript context is untrusted (a compromised CMS could inject code to tamper with verification results), the widget's verification logic runs in an isolated execution context:

**Worker mode (default, `sandbox-mode="worker"`):**
- The widget spawns a dedicated `Worker` from a blob URL containing the verification logic.
- The main thread sends the proof artifact bytes and canonical document bytes to the worker via `postMessage` (using `Transferable` `ArrayBuffer`s for efficiency).
- The worker performs all cryptographic verification and returns a signed result object.
- The worker has no DOM access and cannot be influenced by the hosting page.
- Limitation: the worker cannot access the DOM to extract `innerText`, so canonical text extraction happens in the main thread before dispatch. The worker receives only the pre-extracted bytes and hashes them independently.

**Iframe mode (`sandbox-mode="iframe"`):**
- The widget creates a `<iframe sandbox="allow-scripts" srcdoc="...">` containing the verification logic.
- Communication occurs via `postMessage` with origin checks.
- The iframe has no access to the parent page's DOM, cookies, or storage.
- This mode is more compatible with environments where Worker support is limited.

**Inline mode (`sandbox-mode="inline"`):**
- Verification runs in the main thread within the widget's module scope.
- No isolation from the hosting page. A malicious script on the page could monkey-patch `crypto.subtle`, `fetch`, or `TextEncoder` before the widget loads.
- This mode is NOT RECOMMENDED and the widget logs a console warning when it is active.
- Acceptable only for development/debugging or when the author fully controls the hosting environment.

#### 9.5.3 Proof Source Trust

The proof artifact is fetched from `proof-url`, which the hosting page controls. A compromised page could redirect this URL to a forged proof. Mitigations:

1. **Embedded proof hash**: The page can include a `proof-hash` attribute on the widget element:
   ```html
   <human-verified
     proof-url="/proofs/my-post.json"
     proof-hash="sha256:a1b2c3d4..."
     document-selector="#article-content"
   />
   ```
   The widget computes `SHA-256` of the raw proof bytes before parsing and compares to the declared hash. If they differ, the widget enters the `invalid` state with error code `PROOF_HASH_MISMATCH`.

2. **CORS restrictions**: The proof URL should be served from the same origin or a trusted CDN with restrictive CORS headers. The widget sends `credentials: "omit"` to prevent session-based access control from leaking.

3. **Content-addressing**: When proofs are stored on IPFS, the CID provides inherent content addressing. The widget can verify the CID matches the fetched content.

#### 9.5.4 Network Failure Handling

| Failure Mode | Widget Behavior |
|-------------|-----------------|
| Proof fetch returns HTTP 4xx/5xx | Display `error` state: "Proof not found" (404) or "Server error" (5xx). Show "Retry" button. |
| Proof fetch times out | Display `error` state: "Verification timed out". Show "Retry" button. |
| Registry fetch fails | Proceed with verification; display "Author history unavailable" in detail panel. |
| CORS error | Display `error` state: "Proof could not be loaded (cross-origin restriction)". |
| Offline (navigator.onLine === false) | Display `error` state: "You are offline. Verification requires network access." Listen for `online` event and auto-retry. |

The widget MUST NOT cache a negative result. Failed verifications are retried on each page load or manual retry.

### 9.6 Accessibility

#### 9.6.1 ARIA Attributes

The badge element carries the following ARIA attributes:

```html
<div
  role="status"
  aria-live="polite"
  aria-label="Document verification status: Human Verified, Orb-verified author"
  tabindex="0"
  aria-expanded="false"
  aria-controls="akb-detail-panel"
>
  <!-- badge content -->
</div>
```

- `role="status"` and `aria-live="polite"` ensure screen readers announce the verification result when it changes from "loading" to a final state.
- `aria-label` provides a complete textual description of the badge state.
- `aria-expanded` toggles when the detail panel opens/closes.
- `aria-controls` references the detail panel's `id`.

The detail panel:

```html
<div
  id="akb-detail-panel"
  role="region"
  aria-label="Verification details"
  hidden
>
  <!-- detail content as a definition list <dl> -->
</div>
```

#### 9.6.2 Color-Blind Friendly Design

All verification states are distinguishable without color:

| State | Color | Shape Differentiator | Text Label |
|-------|-------|---------------------|------------|
| Verified Strong | Green | Filled shield + checkmark | "Human Verified" |
| Verified Moderate | Blue | Outlined shield + checkmark | "Human Verified" |
| Verified Weak | Gray | Outlined shield + question mark | "Behavioral Match" |
| Anomaly | Amber | Shield + exclamation mark | "Verified with Anomalies" |
| Invalid | Red | Shield + X mark | "Verification Failed" |

The icons use distinct shapes (checkmark, question mark, exclamation, X) so that states are discriminable in monochrome or to users with any form of color vision deficiency. The plausibility score bars in the detail panel use pattern fills (solid, hatched, dotted) in addition to color gradients.

#### 9.6.3 Keyboard Navigation

- `Tab` focuses the badge element.
- `Enter` or `Space` toggles the detail panel.
- When the detail panel is open, `Tab` moves through interactive elements within the panel (links to proof JSON, verification source code).
- `Escape` closes the detail panel and returns focus to the badge.
- All interactive elements have visible focus indicators (2px solid outline, offset by 2px).

#### 9.6.4 Reduced Motion

The widget respects `prefers-reduced-motion`:

```css
@media (prefers-reduced-motion: reduce) {
  .akb-spinner { animation: none; }
  .akb-detail-panel { transition: none; }
}
```

When reduced motion is preferred, the loading spinner is replaced with a static ellipsis text indicator, and the detail panel appears/disappears instantly without slide animation.

---

## 10. Identity and Discovery

### 10.1 Author Pseudonymous Identity

#### 10.1.1 Derivation

An author's pseudonymous identifier is deterministically derived from their World ID nullifier hash, ensuring that the same person (verified by the same World ID) always produces the same author ID within the Speakwrite application scope, without revealing their World ID or biometric identity.

```
author_id = "human_" ∥ base58(SHA-256(nullifier_hash ∥ "speakwrite_author_v1")[0:20])
```

Step by step:

1. Let `nullifier_hash` be the 256-bit nullifier output from the World ID proof for the `"bind_key"` action.
2. Concatenate `nullifier_hash` (32 bytes, big-endian) with the ASCII bytes of the domain separator string `"speakwrite_author_v1"` (25 bytes).
3. Compute `SHA-256` of the 57-byte input, producing a 32-byte digest.
4. Take the first 20 bytes of the digest.
5. Encode the 20 bytes using Base58 (Bitcoin alphabet: `123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz`).
6. Prepend the fixed prefix `"human_"`.

This produces identifiers of the form `human_7Kx9mPqR3vBnJt5Yw2Hd8LfA` (the `human_` prefix plus approximately 27 Base58 characters). The identifiers are:

- **Stable**: the same World ID user always produces the same identifier.
- **Pseudonymous**: the identifier cannot be reversed to recover the nullifier or the underlying World ID.
- **Collision-resistant**: 160 bits of SHA-256 output provides ~2^80 collision resistance, far exceeding practical thresholds.
- **Scope-bound**: the domain separator ensures that this ID is distinct from any identifier derived for a different application.

#### 10.1.2 Author ID in Proof Artifacts

The `author_id` is included in the proof artifact's `metadata` section:

```json
{
  "metadata": {
    "author_id": "human_7Kx9mPqR3vBnJt5Yw2Hd8LfA",
    "signed_at": "2026-02-13T10:30:00Z",
    "protocol_version": "1.0.0"
  }
}
```

Verifiers recompute the `author_id` from the nullifier in the proof's World ID ZKP and confirm it matches the declared value. This prevents an attacker from claiming a different author's identity.

#### 10.1.3 Optional Profile Metadata

Authors may attach human-readable metadata to their identity. This metadata is NOT part of the proof artifact (it is mutable and non-cryptographic) and is stored in the identity registry (Section 10.2):

```json
{
  "author_id": "human_7Kx9mPqR3vBnJt5Yw2Hd8LfA",
  "display_name": "Satoshi Nakamura",
  "avatar_url": "https://example.com/avatar.jpg",
  "website": "https://satoshinakamura.blog",
  "bio": "Writer, researcher, human.",
  "social_proofs": [
    {
      "platform": "twitter",
      "handle": "@satoshinakamura",
      "proof_url": "https://twitter.com/satoshinakamura/status/123456789"
    },
    {
      "platform": "github",
      "handle": "satoshinakamura",
      "proof_url": "https://gist.github.com/satoshinakamura/abc123"
    }
  ],
  "updated_at": "2026-02-13T10:30:00Z",
  "signature": "<Ed25519 signature of the above fields by the author's bound key>"
}
```

The `social_proofs` array follows the Keybase-style verification pattern: the author publishes a signed statement on each platform linking their `author_id` to that account. The `proof_url` points to the public post containing the statement. Verifiers can optionally crawl these URLs to confirm the link.

The `signature` field covers the entire metadata object (excluding the `signature` field itself), signed with the author's current bound Ed25519 key. This prevents registry operators from tampering with author profiles.

### 10.2 Identity Registry (Optional, Decentralized)

#### 10.2.1 Purpose

The identity registry is an optional service that maps `author_id` values to profile metadata and publication history. It enables:

- Human-readable author names on verification badges.
- Cross-document discovery (finding other verified documents by the same author).
- Aggregate statistics (publication count, consistency scores).

No single central registry is required. Authors self-host their identity using any of the mechanisms below.

#### 10.2.2 Implementation Options

**Option A: DNS TXT Records**

Authors add TXT records to a domain they control:

```
_speakwrite.satoshinakamura.blog. 3600 IN TXT "v=akb1; id=human_7Kx9mPqR3vBnJt5Yw2Hd8LfA; profile=https://satoshinakamura.blog/.well-known/speakwrite-identity"
```

Verifiers perform a DNS lookup for `_speakwrite.<domain>` to discover the author's identity endpoint. The domain itself serves as a weak form of identity verification (the author controls the domain).

**Option B: .well-known HTTP Endpoint**

Authors serve a JSON document at a well-known path on their domain:

```
GET https://satoshinakamura.blog/.well-known/speakwrite-identity
```

Response:

```json
{
  "schema_version": "1.0.0",
  "author_id": "human_7Kx9mPqR3vBnJt5Yw2Hd8LfA",
  "public_key": "<current Ed25519 public key, hex>",
  "display_name": "Satoshi Nakamura",
  "avatar_url": "https://satoshinakamura.blog/avatar.jpg",
  "website": "https://satoshinakamura.blog",
  "bio": "Writer, researcher, human.",
  "social_proofs": [...],
  "publications": [
    {
      "document_hash": "a1b2c3d4...",
      "title": "On the Nature of Human Typing",
      "proof_url": "https://satoshinakamura.blog/proofs/typing-nature.json",
      "published_at": "2026-01-15T08:00:00Z"
    }
  ],
  "aggregate_stats": {
    "publication_count": 12,
    "first_publication": "2026-01-15T08:00:00Z",
    "last_publication": "2026-02-13T10:30:00Z",
    "average_plausibility_score": 0.87,
    "cross_document_consistency_score": 0.82
  },
  "updated_at": "2026-02-13T10:30:00Z",
  "signature": "<Ed25519 signature>"
}
```

The `.well-known` document MUST be served with:
- `Content-Type: application/json`
- `Access-Control-Allow-Origin: *` (to allow widget fetches from any hosting page)
- `Cache-Control: public, max-age=3600`

**Option C: IPFS/IPNS Document**

The identity document is published to IPFS and pinned. The IPNS name is derived from the author's public key:

```
ipns://<author_public_key_multihash>/speakwrite-identity.json
```

This provides censorship resistance and content-addressed integrity. The document format is identical to the `.well-known` format above.

**Option D: Smart Contract Registry**

A simple Solidity contract on Optimism (where World ID already operates) stores the mapping:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract SpeakwriteRegistry {
    struct AuthorRecord {
        bytes32 publicKey;          // Ed25519 public key (first 32 bytes)
        string metadataURI;         // URI to full identity document (IPFS, HTTPS, etc.)
        uint256 publicationCount;
        uint256 registeredAt;
        uint256 updatedAt;
    }

    // author_id (bytes20, derived from nullifier) => AuthorRecord
    mapping(bytes20 => AuthorRecord) public authors;

    // Publication log
    event Publication(
        bytes20 indexed authorId,
        bytes32 indexed documentHash,
        string proofURI,
        uint256 timestamp
    );

    event AuthorRegistered(
        bytes20 indexed authorId,
        bytes32 publicKey,
        string metadataURI,
        uint256 timestamp
    );

    // Registration requires a valid World ID proof (verified via IWorldID interface)
    function register(
        bytes20 authorId,
        bytes32 publicKey,
        string calldata metadataURI,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external { ... }

    // Publish emits an event (gas-efficient discovery)
    function publish(
        bytes20 authorId,
        bytes32 documentHash,
        string calldata proofURI,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external { ... }
}
```

This approach provides permissionless, censorship-resistant identity registration and a queryable publication log via event indexing. The contract verifies World ID proofs on-chain, ensuring only verified humans can register and publish.

#### 10.2.3 .well-known Format Specification

Path: `/.well-known/speakwrite-identity`

MIME type: `application/json`

Required fields:

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | `string` | Must be `"1.0.0"`. |
| `author_id` | `string` | The `human_`-prefixed pseudonymous ID. |
| `public_key` | `string` | Current Ed25519 public key, lowercase hex-encoded (64 characters). |
| `signature` | `string` | Ed25519 signature of all fields (excluding `signature` itself), canonical JSON encoding (sorted keys, no whitespace), lowercase hex-encoded (128 characters). |

Optional fields:

| Field | Type | Description |
|-------|------|-------------|
| `display_name` | `string` | Human-readable name (max 64 UTF-8 characters). |
| `avatar_url` | `string` | URL to an avatar image (HTTPS only, max 256 characters). |
| `website` | `string` | Author's website URL. |
| `bio` | `string` | Short biography (max 256 UTF-8 characters). |
| `social_proofs` | `array` | Array of social proof objects (see 10.1.3). |
| `publications` | `array` | Array of publication record objects (see below). |
| `aggregate_stats` | `object` | Aggregate statistics across all publications. |
| `updated_at` | `string` | ISO 8601 timestamp of last update. |
| `key_history` | `array` | Array of prior public keys with validity ranges (for key rotation). |

Publication record object:

```json
{
  "document_hash": "string (hex, 64 chars)",
  "title": "string (max 256 chars)",
  "proof_url": "string (URL)",
  "published_at": "string (ISO 8601)",
  "verification_level": "orb | device",
  "plausibility_score": "number (0.0-1.0)"
}
```

#### 10.2.4 Registry Trust Model

The identity registry is explicitly untrusted for verification purposes. All claims in the registry (display name, publication count, consistency scores) are convenience data for the UI. The cryptographic verification performed by the widget (Section 9.3) does not depend on registry data.

Registry data is trusted only to the extent that:

1. The `author_id` in the registry matches the `author_id` derived from the proof's nullifier.
2. The registry document is signed by the author's bound key (verifiable against the key in the proof).
3. The publication list can be independently verified by fetching each `proof_url` and checking the proofs.

A malicious registry operator cannot forge proofs, only suppress or reorder listing of legitimate proofs.

### 10.3 Cross-Document Discovery

#### 10.3.1 Discovery Mechanisms

Verifiers who want to find other verified documents by the same author have several discovery paths:

**Registry Publication List**: Query the author's `.well-known` endpoint or smart contract for the `publications` array. Each entry includes a `proof_url` that can be independently fetched and verified.

**On-Chain Event Log**: If the author uses the smart contract registry (Option D), indexers can query `Publication` events filtered by `authorId`. This provides a complete, append-only log of the author's publications with timestamps anchored to block time.

**RSS/Atom Feed**: Authors can publish an RSS or Atom feed of their verified documents:

```
https://satoshinakamura.blog/feeds/speakwrite.xml
```

Each feed entry includes:
- Document title and URL
- `proof_url` as an `<enclosure>` or custom namespace element
- `author_id` as a custom namespace element

Feed namespace:

```xml
<rss version="2.0" xmlns:akb="https://speakwrite.org/rss/1.0">
  <channel>
    <title>Verified Writings by human_7Kx9mPqR3...</title>
    <akb:authorId>human_7Kx9mPqR3vBnJt5Yw2Hd8LfA</akb:authorId>
    <item>
      <title>On the Nature of Human Typing</title>
      <link>https://satoshinakamura.blog/posts/typing-nature</link>
      <akb:proofUrl>https://satoshinakamura.blog/proofs/typing-nature.json</akb:proofUrl>
      <akb:documentHash>a1b2c3d4...</akb:documentHash>
      <pubDate>Wed, 15 Jan 2026 08:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
```

**Link Headers**: Individual document pages can advertise their proof and author identity via HTTP Link headers or `<link>` elements:

```html
<link rel="speakwrite-proof" href="/proofs/typing-nature.json" />
<link rel="speakwrite-author" href="/.well-known/speakwrite-identity" />
```

This allows automated crawlers and browser extensions to discover proofs without parsing page content.

#### 10.3.2 Cross-Document Verification

Given a set of discovered proof URLs for the same `author_id`, a verifier builds the cross-document consistency picture:

1. Fetch and fully verify each proof independently.
2. Confirm all proofs share the same `nullifier_hash` (i.e., same World ID person).
3. Extract `behavioral_summary` from each proof.
4. Compute pairwise behavioral feature correlations across documents (e.g., average typing speed consistency, pause pattern similarity, revision rate stability). The specific metrics are defined in Section 6 (behavioral feature extraction).
5. Compute the aggregate `cross_document_consistency_score` as the mean of pairwise consistency scores, weighted by temporal proximity (recent documents weighted more heavily).

A consistency score above 0.7 indicates stable behavioral patterns consistent with a single human author. Scores below 0.5 may indicate multiple people sharing a World ID (a violation of the protocol's assumptions) or significant behavioral changes (injury, new keyboard, etc.).

### 10.4 Author Profile Aggregation

#### 10.4.1 Aggregate Statistics

Given a set of verified proofs attributed to the same `author_id`, the following aggregate statistics are computed:

| Statistic | Computation |
|-----------|-------------|
| `publication_count` | Count of verified proofs. |
| `first_publication` | Earliest `content_snapshot.published_at` across all proofs. |
| `last_publication` | Latest `content_snapshot.published_at` across all proofs. |
| `average_plausibility_score` | Arithmetic mean of `behavioral_summary.plausibility_score` across all proofs. |
| `cross_document_consistency_score` | Weighted mean of pairwise behavioral consistency (Section 10.3.2, step 5). |
| `behavioral_fingerprint_stability` | Pearson correlation of the author's mean feature vector computed over the first half vs. second half of their publication history. A high value (>0.8) indicates a stable, consistent writing style over time. |
| `anomaly_rate` | Fraction of proofs that have non-empty `anomaly_flags`. |
| `median_session_duration` | Median of `behavioral_summary.session_duration_seconds` across all proofs. |
| `total_keystrokes` | Sum of `behavioral_summary.total_keystrokes` across all proofs. |

#### 10.4.2 Privacy Considerations

Aggregate statistics, while useful for establishing trust, increase the fingerprinting surface. Mitigations:

- Authors control which publications are listed in their registry. They may choose to exclude some.
- The behavioral data in proofs is already aggregated (summary statistics, not raw keystrokes). Cross-document analysis operates on summary-level data only.
- The protocol extension for ZK behavioral proofs (Section 12.1) would eliminate behavioral data exposure entirely.

#### 10.4.3 Reputation Bootstrapping

New authors have no cross-document history. The protocol handles this gracefully:

- First publication: `cross_document_consistency_score` is `null` / not applicable.
- The widget displays "New author -- first verified publication" in the detail panel rather than a low consistency score.
- After 3+ publications, the consistency score becomes meaningful and is displayed normally.
- The `verified-strong` level is achievable on the first publication if orb verification is present (history requirement is waived for `publication_count < 3`).

---

## 11. Implementation Guide

### 11.1 Reference Architecture

```
speakwrite/
├── packages/
│   ├── core/                  # Shared types, schemas, constants, error codes
│   │   ├── src/
│   │   │   ├── types.ts       # TypeScript type definitions for all protocol structures
│   │   │   ├── schemas.ts     # JSON Schema and CBOR schema definitions for validation
│   │   │   ├── constants.ts   # Protocol version, action IDs, hash algorithms, thresholds
│   │   │   ├── errors.ts      # Typed error codes and error factory functions
│   │   │   ├── canonical.ts   # Canonical text extraction and normalization utilities
│   │   │   └── index.ts       # Public API barrel export
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── observer/              # Keystroke capture and raw event recording
│   │   ├── src/
│   │   │   ├── keyboard-observer.ts    # Low-level keydown/keyup/keypress listener
│   │   │   ├── composition-observer.ts # IME composition event handling
│   │   │   ├── clipboard-observer.ts   # Paste/cut event capture
│   │   │   ├── mouse-observer.ts       # Click, selection, cursor position tracking
│   │   │   ├── focus-observer.ts       # Tab/window focus/blur for pause detection
│   │   │   ├── event-buffer.ts         # Ring buffer for high-frequency event batching
│   │   │   ├── privacy-filter.ts       # Strip literal content, retain only timing + metadata
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── extractor/             # Behavioral feature extraction from raw events
│   │   ├── src/
│   │   │   ├── timing-features.ts      # Inter-key intervals, flight times, dwell times
│   │   │   ├── rhythm-features.ts      # N-graph timing patterns, typing cadence
│   │   │   ├── revision-features.ts    # Backspace/delete patterns, edit distance analysis
│   │   │   ├── pause-features.ts       # Pause frequency, duration distribution, location
│   │   │   ├── session-features.ts     # Session duration, break patterns, productivity curve
│   │   │   ├── plausibility.ts         # Human baseline comparison, anomaly detection
│   │   │   ├── aggregator.ts           # Combine features into behavioral summary
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── signer/                # Key management, WorldID integration, proof assembly
│   │   ├── src/
│   │   │   ├── key-manager.ts          # Ed25519 keypair generation, storage, rotation
│   │   │   ├── key-storage.ts          # Secure key storage (IndexedDB + WebCrypto wrapping)
│   │   │   ├── worldid-bind.ts         # Key binding flow via WorldID
│   │   │   ├── worldid-publish.ts      # Per-document publication proof via WorldID
│   │   │   ├── proof-assembler.ts      # Assemble all components into proof artifact
│   │   │   ├── cbor-encoder.ts         # Canonical CBOR encoding (RFC 8949 deterministic)
│   │   │   ├── proof-signer.ts         # Ed25519 signing of canonical payload
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── verifier/              # Standalone verification library (no UI dependency)
│   │   ├── src/
│   │   │   ├── verify.ts               # Main verification entry point
│   │   │   ├── schema-validator.ts     # Proof schema validation
│   │   │   ├── signature-verifier.ts   # Ed25519 signature verification
│   │   │   ├── keybinding-verifier.ts  # Key binding proof verification
│   │   │   ├── worldid-verifier.ts     # World ID ZKP verification (Groth16)
│   │   │   ├── behavioral-evaluator.ts # Behavioral plausibility evaluation
│   │   │   ├── document-hasher.ts      # Canonical text extraction + SHA-256
│   │   │   ├── level-classifier.ts     # Map verification results to trust levels
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── widget/                # Embeddable <human-verified> web component
│   │   ├── src/
│   │   │   ├── human-verified.ts       # Custom element definition
│   │   │   ├── badge.ts               # Badge rendering (Shadow DOM)
│   │   │   ├── detail-panel.ts        # Expandable detail panel
│   │   │   ├── styles.ts             # CSS-in-JS styles (light/dark themes)
│   │   │   ├── i18n.ts               # Localization strings
│   │   │   ├── sandbox-worker.ts      # Worker-based verification sandbox
│   │   │   ├── sandbox-iframe.ts      # Iframe-based verification sandbox
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── cli/                   # Command-line tool for signing and verifying
│       ├── src/
│       │   ├── commands/
│       │   │   ├── sign.ts             # Sign a document from file/stdin
│       │   │   ├── verify.ts           # Verify a proof artifact
│       │   │   ├── keygen.ts           # Generate Ed25519 keypair
│       │   │   ├── bind.ts             # Bind key to WorldID (opens browser flow)
│       │   │   ├── inspect.ts          # Pretty-print proof artifact contents
│       │   │   └── identity.ts         # Manage .well-known identity document
│       │   ├── cli.ts                  # CLI argument parsing (commander.js)
│       │   └── index.ts
│       ├── package.json
│       └── tsconfig.json
│
├── apps/
│   ├── editor/                # TipTap-based writing environment
│   │   ├── src/
│   │   │   ├── App.tsx                 # Main React application shell
│   │   │   ├── Editor.tsx              # TipTap editor with observer integration
│   │   │   ├── extensions/
│   │   │   │   └── speakwrite.ts # TipTap extension hooking observer + extractor
│   │   │   ├── components/
│   │   │   │   ├── SessionPanel.tsx    # Live session stats display
│   │   │   │   ├── PublishDialog.tsx   # WorldID flow + proof generation dialog
│   │   │   │   └── ProofPreview.tsx    # Preview of generated proof artifact
│   │   │   └── hooks/
│   │   │       ├── useObserver.ts      # React hook wrapping observer lifecycle
│   │   │       └── useWorldID.ts       # React hook wrapping IDKit integration
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── demo/                  # Demo site with pre-generated example proofs
│   │   ├── src/
│   │   │   ├── index.html              # Static site with example articles
│   │   │   ├── articles/               # Sample verified articles
│   │   │   └── proofs/                 # Corresponding proof artifacts
│   │   └── package.json
│   │
│   └── registry/              # Optional identity registry HTTP service
│       ├── src/
│       │   ├── server.ts               # Express/Fastify HTTP server
│       │   ├── routes/
│       │   │   ├── identity.ts         # GET/PUT /identity/:author_id
│       │   │   ├── publications.ts     # GET /publications/:author_id
│       │   │   └── aggregate.ts        # GET /aggregate/:author_id
│       │   ├── storage/
│       │   │   ├── sqlite.ts           # SQLite storage backend
│       │   │   └── ipfs.ts             # IPFS storage backend
│       │   └── index.ts
│       ├── package.json
│       └── tsconfig.json
│
├── contracts/                 # Solidity smart contracts (Optimism)
│   ├── src/
│   │   ├── SpeakwriteRegistry.sol
│   │   └── interfaces/
│   │       └── IWorldID.sol
│   ├── test/
│   │   └── Registry.t.sol
│   ├── foundry.toml
│   └── package.json
│
├── spec/                      # Protocol specification documents
│   └── ...
│
├── turbo.json                 # Turborepo pipeline configuration
├── package.json               # Root workspace configuration
├── tsconfig.base.json         # Shared TypeScript configuration
└── README.md
```

### 11.2 Technology Recommendations

#### 11.2.1 Core Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Language** | TypeScript 5.x (strict mode) | Type safety across the monorepo. All packages share `tsconfig.base.json` with `strict: true`, `noUncheckedIndexedAccess: true`, `exactOptionalPropertyTypes: true`. |
| **Build System** | Turborepo | Efficient monorepo builds with caching, dependency-aware task orchestration, and remote cache support. |
| **Package Manager** | pnpm 9.x | Workspace support, strict dependency resolution, disk-efficient. |
| **Bundler** | tsup (for libraries), Vite (for apps and widget) | tsup provides zero-config library bundling with ESM and CJS outputs. Vite for development server and production builds with tree-shaking. |
| **Testing** | Vitest | Fast, TypeScript-native, compatible with Vite's transform pipeline. |

#### 11.2.2 Cryptography

| Operation | Library | Details |
|-----------|---------|---------|
| **Ed25519 signing/verification** | libsodium.js (sumo build) | `crypto_sign_detached` / `crypto_sign_verify_detached`. The sumo build includes all algorithms. WASM variant (`libsodium-wrappers-sumo`) for browser performance. |
| **SHA-256 hashing** | libsodium.js | `crypto_hash_sha256`. Alternatively, use Web Crypto API (`crypto.subtle.digest("SHA-256", data)`) where available, falling back to libsodium in Workers without `crypto.subtle`. |
| **Key generation** | libsodium.js | `crypto_sign_keypair` for Ed25519. Seeds derived from `crypto.getRandomValues` (32 bytes). |
| **Key storage** | Web Crypto API wrapping | Private keys encrypted with AES-GCM using a Web Crypto non-extractable wrapping key. Stored in IndexedDB. The wrapping key is generated via `crypto.subtle.generateKey` and stored in the same IndexedDB, protected by the browser's origin isolation. |
| **CBOR encoding** | cbor-x | Fastest JavaScript CBOR implementation. Use canonical mode (map keys sorted lexicographically) per RFC 8949 Section 4.2.1 for deterministic encoding. |
| **Groth16 verification** | snarkjs (groth16 verifier) | Client-side verification of World ID's Semaphore-based Groth16 proofs. The verification key is embedded in the widget. |

#### 11.2.3 World ID Integration

| Component | Library/Service | Details |
|-----------|----------------|---------|
| **Client-side proof generation** | `@worldcoin/idkit` v1.x | React component or vanilla JS API for QR code / World App deeplink flow. |
| **Server-side proof verification** | World ID Developer Portal API or on-chain | `POST https://developer.worldcoin.org/api/v2/verify/{app_id}` for cloud verification. On-chain: call `IWorldID.verifyProof()` on the deployed World ID contract. |
| **On-chain verification** | `@worldcoin/world-id-contracts` | Solidity interfaces for on-chain proof verification. Deployed on Optimism mainnet. |

#### 11.2.4 Editor

| Component | Technology | Details |
|-----------|-----------|---------|
| **Rich text editor** | TipTap 2.x (ProseMirror-based) | Excellent programmatic access to editor transactions, input rules, and DOM events. Extensions API for clean integration. |
| **Framework** | React 18.x (for the editor app) | TipTap's `@tiptap/react` provides first-class React bindings. The editor app uses React; the core packages and widget are framework-agnostic. |

#### 11.2.5 Widget

| Component | Technology | Details |
|-----------|-----------|---------|
| **Web component** | Vanilla custom elements + Shadow DOM | No framework dependency. The widget is a single `HTMLElement` subclass. Lit (lit-element) may be used if template complexity warrants it, but for the current scope, vanilla `attachShadow` with template literals suffices. |
| **WASM** | libsodium WASM | Embedded in the widget bundle via inline base64 or fetched from a CDN with SRI. |

#### 11.2.6 Smart Contracts

| Component | Technology | Details |
|-----------|-----------|---------|
| **Language** | Solidity 0.8.24+ | Latest stable compiler with custom error support and overflow checks. |
| **Framework** | Foundry (forge, cast, anvil) | Fast compilation, testing with Solidity tests, deployment scripting. |
| **Chain** | Optimism Mainnet / Optimism Sepolia (testnet) | World ID contracts are deployed on Optimism. Collocating the registry minimizes cross-chain complexity. |

### 11.3 Editor Integration Patterns

#### 11.3.1 TipTap Extension Architecture

The Speakwrite observer integrates with TipTap as a custom extension:

```typescript
import { Extension } from "@tiptap/core";
import { Plugin, PluginKey } from "@tiptap/pm/state";
import { KeyboardObserver, CompositionObserver, ClipboardObserver } from "@speakwrite/observer";
import { FeatureExtractor } from "@speakwrite/extractor";

const speakwritePluginKey = new PluginKey("speakwrite");

export const Speakwrite = Extension.create({
  name: "speakwrite",

  addProseMirrorPlugins() {
    const observer = new KeyboardObserver();
    const compositionObserver = new CompositionObserver();
    const clipboardObserver = new ClipboardObserver();
    const extractor = new FeatureExtractor();

    return [
      new Plugin({
        key: speakwritePluginKey,

        props: {
          // Intercept DOM events at the ProseMirror level
          handleDOMEvents: {
            keydown: (view, event) => {
              observer.recordKeyDown(event);
              return false; // Do not consume the event
            },
            keyup: (view, event) => {
              observer.recordKeyUp(event);
              return false;
            },
            compositionstart: (view, event) => {
              compositionObserver.recordStart(event);
              return false;
            },
            compositionupdate: (view, event) => {
              compositionObserver.recordUpdate(event);
              return false;
            },
            compositionend: (view, event) => {
              compositionObserver.recordEnd(event);
              return false;
            },
            paste: (view, event) => {
              clipboardObserver.recordPaste(event, view.state.selection);
              return false;
            },
          },
        },

        // Track document mutations for revision analysis
        appendTransaction(transactions, _oldState, newState) {
          for (const tr of transactions) {
            if (tr.docChanged) {
              extractor.recordTransaction({
                steps: tr.steps.length,
                timestamp: Date.now(),
                docSize: newState.doc.content.size,
                selectionFrom: tr.selection.from,
                selectionTo: tr.selection.to,
              });
            }
          }
          return null; // No additional transactions to append
        },
      }),
    ];
  },
});
```

Key design points:

- **`handleDOMEvents` returns `false`**: The observer never consumes events. It passively records them without interfering with TipTap's normal input handling. Returning `false` ensures the event continues to propagate through ProseMirror's input pipeline.
- **`appendTransaction`**: This ProseMirror plugin hook fires after every transaction (including those from collaborators, input rules, or programmatic changes). It records structural document mutations for revision analysis.
- **Separation of concerns**: The observer records raw events. The extractor processes them. The extension just wires them to ProseMirror's event system.

#### 11.3.2 DOM Event Interception

The observer captures the following DOM events on the editor's `contenteditable` element:

| Event | Data Captured | Privacy Note |
|-------|--------------|--------------|
| `keydown` | `timestamp` (ms, `performance.now()`), `code` (physical key, e.g., `"KeyA"`), `key` (logical key, discarded after classification), `shiftKey`, `ctrlKey`, `altKey`, `metaKey`, `repeat` flag | The `key` value (actual character) is used only to classify the event type (letter, digit, punctuation, modifier, navigation, editing) and is NOT stored. Only the classification enum and `code` are retained. |
| `keyup` | `timestamp`, `code` | Used to compute dwell time (keydown-to-keyup for same `code`). |
| `compositionstart` | `timestamp` | Marks the beginning of an IME composition (CJK input, etc.). |
| `compositionupdate` | `timestamp`, `data.length` (character count, NOT content) | Tracks composition progress without recording the actual characters. |
| `compositionend` | `timestamp`, `data.length` | Marks composition completion. |
| `paste` | `timestamp`, `data.length` (character count), `source` classification (`"clipboard"`) | The pasted content is NOT stored. Only the length and the fact that a paste occurred are recorded. |
| `focus` / `blur` | `timestamp`, `type` | Tracks when the author tabs away, enabling pause detection. |

#### 11.3.3 Performance Considerations

The observer must not degrade the typing experience. Targets:

| Metric | Target | Strategy |
|--------|--------|----------|
| Event handler latency | < 0.1 ms per event | Handlers only push to a ring buffer. No computation, no memory allocation beyond the pre-allocated buffer. |
| Memory overhead | < 2 MB for a 2-hour session | Ring buffer of 50,000 events (each ~40 bytes). Older events are evicted when the buffer is full. Feature extraction summarizes before eviction. |
| Main thread blocking | Zero perceptible jank | Feature extraction runs in 10 ms chunks scheduled via `requestIdleCallback` or in a Web Worker. Never runs synchronously in the event handler path. |
| Battery impact | Negligible | No polling. All capture is event-driven. `performance.now()` is the only timer API used (no `setInterval`). |

#### 11.3.4 Event Buffering Strategy

Events are stored in a pre-allocated ring buffer (`ArrayBuffer`-backed for GC friendliness):

```typescript
class EventRingBuffer {
  private buffer: Float64Array;  // Timestamp + encoded event data
  private head: number = 0;
  private count: number = 0;
  private readonly capacity: number;

  constructor(capacity: number = 50_000) {
    // Each event: 4 Float64 slots = 32 bytes
    // [timestamp, eventType, keyCode, flags]
    this.capacity = capacity;
    this.buffer = new Float64Array(capacity * 4);
  }

  push(timestamp: number, eventType: number, keyCode: number, flags: number): void {
    const offset = (this.head % this.capacity) * 4;
    this.buffer[offset] = timestamp;
    this.buffer[offset + 1] = eventType;
    this.buffer[offset + 2] = keyCode;
    this.buffer[offset + 3] = flags;
    this.head++;
    this.count = Math.min(this.count + 1, this.capacity);
  }
}
```

When the buffer approaches capacity (80% full), the extractor is triggered to process the oldest 50% of events into summary features. The processed events are then available for eviction. This ensures that long writing sessions never lose critical data and that memory usage remains bounded.

### 11.4 WorldID Integration Details

#### 11.4.1 Developer Portal Setup

1. Navigate to the [World ID Developer Portal](https://developer.worldcoin.org).
2. Create a new application (e.g., "Speakwrite").
3. Note the `app_id` (format: `app_<uuid>`).
4. Register the following actions:

| Action ID | Description | Max Verifications | Signal | Notes |
|-----------|-------------|-------------------|--------|-------|
| `bind_key` | Bind an Ed25519 public key to a World ID identity. | 1 per person (with rotation via `rebind_key`) | `SHA-256(public_key)` | This is the identity-binding step. A person can only bind one key at a time. |
| `publish` | Sign a document publication. | Unlimited | `SHA-256(document_hash ∥ published_at)` | Each document gets its own proof. The "unlimited" max allows the same person to publish many documents. |
| `rebind_key` | Rotate to a new Ed25519 public key, invalidating the previous one. | Unlimited (rate-limited in practice) | `SHA-256(new_public_key ∥ old_public_key)` | Includes a reference to the old key so verifiers can chain the rotation history. |

5. Configure the allowed origins for the IDKit widget (the domains where your editor app will run).

#### 11.4.2 Key Binding Flow

The key binding flow is the critical one-time setup step where a verified human associates their Ed25519 signing key with their World ID:

```
Author                    Editor App                 World App / Orb           WorldID API
  │                           │                           │                       │
  ├── Click "Bind Identity" ──┤                           │                       │
  │                           ├── Generate Ed25519 ───────┤                       │
  │                           │   keypair (if needed)     │                       │
  │                           │                           │                       │
  │                           ├── Open IDKit with ────────┤                       │
  │                           │   action="bind_key"       │                       │
  │                           │   signal=H(pub_key)       │                       │
  │                           │                           │                       │
  │  ◄── Scan QR / deeplink ──┤                           │                       │
  │                           │                           │                       │
  ├── Verify with World App ──┼───────────────────────────┤                       │
  │   (face scan if orb)      │                           │                       │
  │                           │                           │                       │
  │                           │  ◄── ZKP returned ────────┤                       │
  │                           │   (merkle_root, nullifier,│                       │
  │                           │    proof[8])              │                       │
  │                           │                           │                       │
  │                           ├── Verify proof server-side┼───────────────────────┤
  │                           │   or on-chain             │                       │
  │                           │                           │                       │
  │                           ├── Store key_binding = {   │                       │
  │                           │     public_key,           │                       │
  │                           │     worldid_proof: {      │                       │
  │                           │       merkle_root,        │                       │
  │                           │       nullifier_hash,     │                       │
  │                           │       proof,              │                       │
  │                           │       verification_level  │                       │
  │                           │     },                    │                       │
  │                           │     bound_at: ISO8601     │                       │
  │                           │   }                       │                       │
  │                           │                           │                       │
  │  ◄── "Identity bound" ────┤                           │                       │
```

IDKit integration code:

```typescript
import { IDKitWidget, VerificationLevel } from "@worldcoin/idkit";

function BindIdentityButton({ publicKey }: { publicKey: Uint8Array }) {
  const signal = sha256(publicKey); // H(public_key)

  const handleVerify = async (proof: ISuccessResult) => {
    // Server-side verification (recommended) or on-chain
    const response = await fetch("/api/verify-bind", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        proof,
        public_key: hex(publicKey),
      }),
    });

    if (!response.ok) throw new Error("Verification failed");

    const keyBinding = await response.json();
    await keyManager.storeKeyBinding(keyBinding);
  };

  return (
    <IDKitWidget
      app_id={process.env.WORLDID_APP_ID!}
      action="bind_key"
      signal={signal}
      verification_level={VerificationLevel.Orb} // Request highest level
      onSuccess={handleVerify}
    >
      {({ open }) => (
        <button onClick={open}>Verify Identity with World ID</button>
      )}
    </IDKitWidget>
  );
}
```

#### 11.4.3 Per-Document Publication Flow

Each time an author publishes a verified document, they generate a fresh World ID proof:

```typescript
async function publishDocument(
  documentHash: string,
  publishedAt: string, // ISO 8601
  keyManager: KeyManager,
): Promise<WorldIDPublicationProof> {
  const signal = sha256(
    concat(hexToBytes(documentHash), utf8ToBytes(publishedAt))
  );

  return new Promise((resolve, reject) => {
    // Programmatic IDKit invocation
    IDKit.open({
      app_id: process.env.WORLDID_APP_ID!,
      action: "publish",
      signal: signal,
      verification_level: VerificationLevel.Orb,
      onSuccess: async (proof) => {
        // Verify server-side
        const response = await fetch("/api/verify-publish", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            proof,
            document_hash: documentHash,
            published_at: publishedAt,
          }),
        });

        if (!response.ok) {
          reject(new Error("Publication verification failed"));
          return;
        }

        resolve({
          merkle_root: proof.merkle_root,
          nullifier_hash: proof.nullifier_hash,
          proof: proof.proof,
          verification_level: proof.verification_level,
          signal: signal,
        });
      },
      onError: reject,
    });
  });
}
```

#### 11.4.4 Server-Side Proof Verification

```typescript
// Using the World ID Developer Portal API
async function verifyWorldIDProof(
  proof: WorldIDProof,
  action: string,
  signal: string,
): Promise<boolean> {
  const response = await fetch(
    `https://developer.worldcoin.org/api/v2/verify/${process.env.WORLDID_APP_ID}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        merkle_root: proof.merkle_root,
        nullifier_hash: proof.nullifier_hash,
        proof: proof.proof,
        action: action,
        signal: signal,
      }),
    },
  );

  if (response.status === 200) {
    return true;
  }

  const error = await response.json();
  // Common error codes:
  // "invalid_merkle_root" - root is too old or invalid
  // "invalid_proof" - ZKP verification failed
  // "already_verified" - nullifier already used for this action (bind_key is one-time)
  throw new WorldIDVerificationError(error.code, error.detail);
}
```

On-chain alternative (for maximum decentralization):

```solidity
import { IWorldID } from "@worldcoin/world-id-contracts/interfaces/IWorldID.sol";

function verifyPublicationOnChain(
    IWorldID worldId,
    uint256 groupId,       // 1 for orb-verified
    uint256 root,
    uint256 nullifierHash,
    uint256 signal,
    uint256[8] calldata proof
) internal {
    worldId.verifyProof(
        root,
        groupId,
        signal,
        nullifierHash,
        abi.encodePacked(ACTION_ID_PUBLISH).hashToField(),
        proof
    );
}
```

#### 11.4.5 Handling Verification Level Differences

World ID supports two verification levels:

| Level | Method | Trust | Use in Speakwrite |
|-------|--------|-------|------------------------|
| `orb` | Iris scan at a Worldcoin Orb device | High: biometric uniqueness guarantee. Each human can only verify once. | Enables `verified-strong` status. Recommended for authors who want maximum credibility. |
| `device` | Phone number verification via World App | Moderate: one phone per identity, but phone numbers can be acquired. | Enables `verified-moderate` status. Lower barrier to entry. |

The protocol treats both levels as valid but surfaces the distinction in the verification badge:

- If the author bound their key with `orb` level, the proof artifact records `verification_level: "orb"`, and the widget can display "Orb-verified author".
- If `device` level, the widget displays "Device-verified author".
- The author can upgrade from `device` to `orb` by re-binding their key with a new World ID proof at `orb` level (using the `rebind_key` action).

### 11.5 Deployment Models

#### 11.5.1 Self-Hosted

In the self-hosted model, the author operates the entire Speakwrite stack:

```
┌─────────────────────────────────────────────────────┐
│ Author's Infrastructure                             │
│                                                     │
│  ┌────────────┐  ┌────────────┐  ┌───────────────┐  │
│  │  Editor     │  │  Signer    │  │  Proof Store  │  │
│  │  (TipTap)  │──│  (local)   │──│  (/proofs/)   │  │
│  └────────────┘  └────────────┘  └───────────────┘  │
│                                                     │
│  ┌────────────────────────────────────────────────┐  │
│  │  Blog / Website                                │  │
│  │  - Article HTML                                │  │
│  │  - <human-verified> widget                     │  │
│  │  - .well-known/speakwrite-identity       │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

Workflow:
1. Author writes in the TipTap editor (hosted locally or on their server).
2. Observer captures keystrokes; extractor computes features.
3. On publish, the signer assembles the proof artifact (triggering World ID flow via IDKit).
4. Proof artifact is saved to the author's web server (e.g., `/proofs/my-post.json`).
5. Article page includes the `<human-verified>` widget pointing to the proof URL.
6. Author updates their `.well-known/speakwrite-identity` document with the new publication.

Requirements: the author must serve their domain over HTTPS and have a World ID account.

#### 11.5.2 Platform-Integrated

CMS platforms (WordPress, Ghost, Substack-like systems) integrate Speakwrite as a plugin:

```
┌───────────────────────────────────────────────────────────────┐
│ CMS Platform                                                  │
│                                                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Speakwrite Plugin                                 │  │
│  │                                                          │  │
│  │  ┌────────────┐ ┌────────────┐ ┌───────────────────────┐ │  │
│  │  │  Observer   │ │  Extractor │ │  Signer               │ │  │
│  │  │  (injected  │ │  (client-  │ │  (client-side key,    │ │  │
│  │  │   into CMS  │ │   side)    │ │   WorldID via IDKit)  │ │  │
│  │  │   editor)   │ │            │ │                       │ │  │
│  │  └────────────┘ └────────────┘ └───────────────────────┘ │  │
│  │                                                          │  │
│  │  Post-publish hook:                                      │  │
│  │  - Store proof in CMS media library                      │  │
│  │  - Inject <human-verified> widget into post template     │  │
│  │  - Update author's identity record                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                               │
│  Readers see the widget on published posts.                    │
└───────────────────────────────────────────────────────────────┘
```

**WordPress Plugin Architecture:**
- A PHP plugin registers a TipTap-based block editor replacement (or augments Gutenberg with a custom block that includes the observer).
- The observer JavaScript is enqueued on the post editor page.
- On publish, a client-side hook assembles the proof and uploads it as a WordPress media attachment.
- The plugin injects the `<human-verified>` element into the post template via a `the_content` filter.
- The plugin provides a settings page for World ID `app_id` configuration and key management.

**Ghost Integration:**
- Ghost's editor is Mobiledoc/Koenig-based. A custom card type or editor extension injects the observer.
- The integration layer adapts the observer to Ghost's editor event model (which differs from ProseMirror).
- Proofs are stored as Ghost content files or on an external store configured by the site owner.

#### 11.5.3 Hybrid

The hybrid model separates writing (in a hosted Speakwrite editor) from publishing (on the author's own domain):

```
┌─────────────────────────┐          ┌────────────────────────────┐
│ Hosted Editor            │          │ Author's Domain             │
│ (editor.speakwrite │          │                            │
│  .org)                   │          │  ┌────────────────────────┐ │
│                          │          │  │  Blog / Website        │ │
│ - TipTap + Observer      │  export  │  │  - Article HTML        │ │
│ - Feature Extraction     │────────► │  │  - <human-verified>    │ │
│ - WorldID Binding        │  proof   │  │  - /proofs/*.json      │ │
│ - Proof Generation       │  + HTML  │  └────────────────────────┘ │
│                          │          │                            │
└─────────────────────────┘          └────────────────────────────┘
```

Workflow:
1. Author writes in the hosted editor at `editor.speakwrite.org`.
2. All observation, extraction, and signing happen client-side in the hosted editor.
3. The editor's private key is stored in the browser's IndexedDB for the editor's origin (never sent to the server).
4. On publish, the editor exports: (a) the article HTML, (b) the proof artifact JSON, and (c) a `<human-verified>` snippet configured for the author's domain.
5. The author uploads these files to their domain.
6. Readers on the author's domain verify via the widget, which fetches the co-hosted proof.

This model provides the best editor experience (purpose-built for Speakwrite) while preserving the author's sovereignty over their content and proofs. The hosted editor NEVER has access to the private key or World ID credentials; these remain client-side.

---

## 12. Protocol Extensions (Future Work)

This section describes potential extensions to the Speakwrite protocol. Each subsection is annotated with a maturity assessment ranging from **achievable near-term** (could be implemented with current technology and moderate engineering effort) to **research-stage** (requires advances in underlying technology or significant open questions).

### 12.1 ZK Behavioral Proofs

**Maturity: Research-stage.**

#### 12.1.1 Motivation

The current protocol publishes aggregated behavioral statistics (typing speed distributions, pause patterns, revision rates) in the proof artifact. While these are summary-level and do not contain raw keystrokes, they constitute a behavioral biometric that could theoretically be used for fingerprinting or de-anonymizing authors across pseudonymous identities.

Zero-knowledge behavioral proofs would allow an author to prove:

1. *"My behavioral features fall within established human baseline ranges"* -- without revealing the specific feature values.
2. *"My behavioral features are consistent with my historical pattern"* -- without revealing either the current or historical patterns.

This is the gold standard for privacy: the verifier learns only the boolean result, not the underlying data.

#### 12.1.2 Technical Approach

The core operation to prove in zero knowledge is:

```
Given:
  - Private input: feature_vector (N floating-point values)
  - Private input: historical_mean_vector (N floating-point values)
  - Private input: historical_stddev_vector (N floating-point values)
  - Public input: human_baseline_ranges (N min/max pairs)
  - Public input: consistency_threshold (scalar)

Prove:
  1. For each i in 0..N:
     human_baseline_ranges[i].min <= feature_vector[i] <= human_baseline_ranges[i].max
  2. consistency_score = mean(
       for each i in 0..N:
         1 - |feature_vector[i] - historical_mean[i]| / (3 * historical_stddev[i])
     )
     consistency_score >= consistency_threshold
```

This requires a ZK circuit that performs:
- Floating-point (or fixed-point) arithmetic: range comparisons, absolute value, division, mean.
- Over approximately N = 50-100 feature dimensions.

#### 12.1.3 Candidate ZK Systems

| System | Suitability | Notes |
|--------|------------|-------|
| **SP1** (Succinct) | Promising | General-purpose zkVM that compiles Rust programs to ZK proofs. Could implement feature comparison in Rust and generate a proof. Proof generation is computationally expensive (minutes on modern hardware) but verification is fast. |
| **Halo2** (PSE/Zcash) | Suitable with effort | Provides custom gates and lookup tables that could efficiently encode fixed-point arithmetic. Requires manual circuit design. No trusted setup. |
| **PLONK** (various implementations) | Suitable with effort | Universal trusted setup. Mature tooling. Similar circuit complexity to Halo2. |
| **Noir** (Aztec) | Promising | High-level ZK language compiling to ACIR. Could express the feature comparison as readable Noir code. Newer ecosystem. |

#### 12.1.4 Challenges

- **Floating-point in ZK**: ZK circuits operate over finite fields, not floating-point numbers. Feature values must be represented as fixed-point integers (e.g., multiply all values by 10^6 and work in integer arithmetic). This is achievable but requires careful handling of precision and overflow.
- **Proof generation time**: Current ZK systems would require 10-60 seconds to generate a behavioral proof on a consumer device. This is acceptable for a publish action but not for real-time verification.
- **Circuit size**: N=100 feature dimensions with comparison and consistency computation produces a circuit of approximately 10,000-50,000 constraints. This is within the practical range for PLONK/Halo2 but would benefit from optimization.
- **Historical commitment**: To prove consistency with historical data, the author must commit to their historical feature distribution. This requires either a trusted accumulator or a Merkle tree of historical feature vectors, adding protocol complexity.

#### 12.1.5 Privacy Benefit

If realized, ZK behavioral proofs would eliminate all biometric data from the proof artifact. The proof would contain only:

- A ZKP attesting "behavioral features are human-plausible and self-consistent."
- Cryptographic commitments to the (hidden) feature data for future consistency proofs.
- All existing non-behavioral fields (document hash, signature, World ID proof).

This would make Speakwrite proofs fully privacy-preserving: no behavioral fingerprint, no biometric leakage, only a boolean attestation of humanity.

### 12.2 Collaborative Writing

**Maturity: Achievable near-term.**

#### 12.2.1 Protocol Extension

Multi-author documents require attributing each portion of the text to a specific verified human. The proof artifact is extended to support per-author segments:

```json
{
  "collaborative": true,
  "authors": [
    {
      "author_id": "human_7Kx9mPqR3...",
      "worldid_proof": { ... },
      "key_binding": { ... },
      "behavioral_summary": { ... },
      "segments": [
        {
          "start_offset": 0,
          "end_offset": 4523,
          "content_hash": "sha256 of segment text"
        },
        {
          "start_offset": 8901,
          "end_offset": 12340,
          "content_hash": "..."
        }
      ],
      "signature": "Ed25519 signature covering this author's segments and behavioral data"
    },
    {
      "author_id": "human_Mn3pQr8Ks...",
      "worldid_proof": { ... },
      "key_binding": { ... },
      "behavioral_summary": { ... },
      "segments": [ ... ],
      "signature": "..."
    }
  ],
  "content_snapshot": {
    "document_hash": "hash of full document",
    "segment_merkle_root": "Merkle root of all segment hashes"
  }
}
```

#### 12.2.2 Capture Strategy

In a collaborative editor (e.g., TipTap with Yjs or Hocuspocus collaboration backend):

1. Each collaborator runs their own observer instance locally.
2. The collaboration protocol tags each edit with the originating user's client ID.
3. Segment attribution is derived from the collaboration protocol's operation log: each character in the final document is attributed to the author whose insert operation created it.
4. Each author signs only their own segments and behavioral data. The full document hash is included for context, but individual signatures cover per-author data only.

#### 12.2.3 Verification

The widget verifies each author's contribution independently:

1. Verify each author's signature, key binding, and World ID proof.
2. Verify each author's behavioral summary.
3. Reconstruct the segment Merkle tree from declared segments and verify against `segment_merkle_root`.
4. Verify that segments cover the entire document without gaps or overlaps (modulo a small tolerance for collaborative merge artifacts).
5. Display per-author verification status in the detail panel.

### 12.3 AI-Assisted Writing Tier

**Maturity: Achievable near-term.**

#### 12.3.1 Motivation

The binary distinction between "human-authored" and "AI-generated" is increasingly inadequate. Many authors use AI tools for brainstorming, drafting, editing, or polishing. Speakwrite should support an honest middle ground: transparently disclosing AI assistance while still verifying human involvement.

#### 12.3.2 Detection Signals

The observer can detect AI-assisted patterns through behavioral analysis:

| Signal | Detection Method | Interpretation |
|--------|-----------------|----------------|
| Large paste events | Clipboard observer detects paste of >50 characters | Content likely sourced externally (could be AI, could be any copy-paste). |
| Paste-then-edit pattern | Large paste followed by character-level edits | Human is revising externally-sourced content. |
| Typing speed anomalies | Sudden shift to superhuman typing speed in a segment | Possible automated input (though some fast typists exist). |
| Session gaps with content changes | Document changes during a period with no keyboard events | Content may have been programmatically inserted. |
| Revision absence | Long passages with zero backspace/delete events | Unusual for human composition; more typical of pasted content. |

#### 12.3.3 Verification Levels

| Level | Criteria | Badge Text |
|-------|----------|------------|
| `HUMAN_AUTHORED` | All content shows organic typing patterns. Paste events are minimal (<5% of characters) and consistent with normal reference checking. | "Written by a verified human" |
| `HUMAN_ASSISTED` | Significant portions (>5% of characters) were pasted from external sources, but a verified human performed substantive editing, restructuring, and revision. Behavioral data confirms active human engagement throughout. | "Written by a verified human with AI assistance" |
| `HUMAN_CURATED` | Majority of content was pasted with minimal human editing. Behavioral data shows review and selection activity but not substantive composition. | "Curated by a verified human" |

#### 12.3.4 Proof Artifact Extension

```json
{
  "authorship_tier": "HUMAN_ASSISTED",
  "composition_breakdown": {
    "typed_characters": 8234,
    "pasted_characters": 3421,
    "paste_ratio": 0.294,
    "paste_events": [
      {
        "timestamp_offset": 1234.5,
        "character_count": 842,
        "subsequent_edits": 47,
        "edit_ratio": 0.056
      }
    ],
    "human_engagement_score": 0.78
  }
}
```

The `human_engagement_score` combines typing ratio, revision depth on pasted content, and session duration relative to document length. It provides a scalar summary of how much human work went into the document.

#### 12.3.5 Design Philosophy

This extension prioritizes **transparency over enforcement**. It does not block AI-assisted content; it labels it honestly. This respects the reality that AI tools are useful, while giving readers the information they need to assess authorship. The protocol's value is in verification and disclosure, not gatekeeping.

### 12.4 Mobile and Alternative Input

**Maturity: Achievable medium-term.**

#### 12.4.1 Touch-Screen Typing

Mobile keyboard input produces different behavioral signals than desktop:

| Feature | Desktop | Mobile |
|---------|---------|--------|
| Inter-key timing | 50-200 ms typical | 80-350 ms typical (thumb typing) |
| Dwell time | Measurable per physical key | Often unavailable (touch events fire on release) |
| Key travel | Physical distance | Touch area / pressure (where available) |
| Autocorrect | Minimal | Frequent (modifies text after entry) |
| Swipe input | N/A | Continuous gesture, no per-key events |

The observer must be adapted to capture `touchstart`/`touchend` events on the virtual keyboard area (where accessible), as well as `input` and `beforeinput` events that capture the result of autocorrect and swipe input. Behavioral features must be recalibrated with mobile-specific baselines.

#### 12.4.2 Voice-to-Text Input

Voice input produces no keystroke events at all. Instead:

- The `SpeechRecognition` API fires `result` events with transcript segments.
- Behavioral features shift to speech-domain: pause durations between utterances, speaking rate, correction patterns, filler word frequency.
- This is a fundamentally different behavioral signal and would require a separate feature extractor and baseline model.

#### 12.4.3 Hybrid Input

Real-world authoring often combines input methods: dictating a rough draft, then editing on keyboard. The observer should track input method transitions and compute behavioral features per-method. The proof artifact would include method-specific behavioral summaries:

```json
{
  "behavioral_summary": {
    "input_methods": ["keyboard", "voice", "touch"],
    "keyboard_summary": { ... },
    "voice_summary": { ... },
    "touch_summary": { ... },
    "overall_plausibility_score": 0.82
  }
}
```

#### 12.4.4 Accessibility Considerations

Authors with motor impairments may have behavioral patterns that fall outside "typical" baselines:

- Slower typing speeds.
- Higher error/correction rates.
- Use of assistive input devices (switch access, eye tracking, head tracking).

The protocol must NOT penalize these patterns. The human baseline ranges (Section 8.4.4) should be wide enough to accommodate the full spectrum of human typing ability. Anomaly detection should focus on non-human patterns (e.g., perfectly uniform inter-key intervals, zero corrections over thousands of characters) rather than on deviation from a "normal" human model.

Where assistive technology produces input events that are indistinguishable from automated input (e.g., single-switch scanning produces evenly-timed character insertion), the protocol should support an `accessibility_mode` flag in the proof that adjusts baseline expectations. This flag does not weaken the verification; it shifts which behavioral features are weighted.

### 12.5 Decentralized Timestamping

**Maturity: Achievable near-term.**

#### 12.5.1 Motivation

The `published_at` timestamp in the proof artifact is self-declared by the author. A malicious author could backdate a proof to claim they wrote something before a certain event. Decentralized timestamping provides independent temporal anchoring.

#### 12.5.2 Mechanisms

**OpenTimestamps (Bitcoin-anchored):**

1. After generating the proof artifact, compute `SHA-256(proof_artifact_bytes)`.
2. Submit the hash to the OpenTimestamps calendar servers.
3. The calendar servers aggregate many hashes into a Merkle tree and commit the root to a Bitcoin `OP_RETURN` transaction.
4. After the Bitcoin transaction confirms (~1-6 blocks, 10-60 minutes), the OpenTimestamps proof is available.
5. Include the OpenTimestamps proof (a compact Merkle path + Bitcoin block reference) in the proof artifact or as a sidecar file.

Verification: anyone can verify the OpenTimestamps proof against the Bitcoin blockchain, confirming that the proof artifact existed at or before the Bitcoin block's timestamp.

**Ethereum Event Log:**

If using the on-chain registry (Section 10.2.2, Option D), the `Publication` event provides a timestamp anchored to the Optimism block time. This is already part of the registry flow and requires no additional mechanism.

**Transparency Log:**

A Certificate Transparency-style append-only log operated by the Speakwrite community or a neutral third party. Authors submit proof hashes, and the log periodically publishes signed tree heads. This provides lightweight timestamping without blockchain fees.

#### 12.5.3 Incremental Commitments

For stronger temporal proof, the author can publish incremental commitments during the writing process:

1. Every T minutes (e.g., T=30), the observer computes a commitment: `H(document_state ∥ behavioral_summary_so_far ∥ timestamp)`.
2. These commitments are submitted to a timestamping service.
3. The final proof artifact includes the chain of incremental commitments.
4. Verifiers can confirm that the writing process unfolded over time (not fabricated all at once).

This is particularly powerful against retroactive proof fabrication: an attacker would need to submit fake incremental commitments at realistic intervals, which requires advance planning.

### 12.6 Interoperability

**Maturity: Achievable near-term (for C2PA); medium-term (for broader ecosystem).**

#### 12.6.1 Content Credentials (C2PA) Integration

The Coalition for Content Provenance and Authenticity (C2PA) defines a standard for embedding provenance metadata in media files. Speakwrite proofs can be embedded as a C2PA assertion within the content's manifest:

```json
{
  "claim": {
    "assertions": [
      {
        "label": "org.speakwrite.humanAuthorship",
        "data": {
          "author_id": "human_7Kx9mPqR3...",
          "verification_level": "orb",
          "plausibility_score": 0.87,
          "proof_url": "https://example.com/proofs/my-post.json",
          "proof_hash": "sha256:a1b2c3d4..."
        }
      }
    ]
  }
}
```

This allows C2PA-aware platforms (Adobe Content Authenticity Initiative tools, news organizations, social media platforms) to recognize and display Speakwrite verification alongside other provenance information (camera metadata, editing history, etc.).

#### 12.6.2 Integration Pattern

1. Author generates the Speakwrite proof artifact as normal.
2. If the content is packaged as a C2PA-compatible format (JPEG, PNG, PDF, HTML), the proof reference is embedded as a custom C2PA assertion.
3. The C2PA manifest is signed with the author's C2PA credential (which may be the same Ed25519 key or a separate X.509 certificate).
4. Consumers who understand C2PA see the Speakwrite assertion in the provenance chain.
5. Consumers who don't understand C2PA can still verify via the standalone `<human-verified>` widget.

#### 12.6.3 Cross-Platform Proof Portability

Speakwrite proofs are designed to be portable:

- **Format**: JSON (human-readable) or CBOR (compact). Both are platform-agnostic.
- **Verification**: The verifier library has zero platform dependencies (runs in browsers, Node.js, Deno, and can be compiled to native via wasm2c or rewritten in any language).
- **No lock-in**: Proofs are self-contained. They include all data needed for verification (public key, World ID proof, behavioral summary, document hash). No ongoing dependency on Speakwrite infrastructure.
- **Archival**: Proofs remain verifiable indefinitely as long as the World ID Merkle root can be queried (either from the on-chain contract or from an archived snapshot of the Merkle tree).

#### 12.6.4 Standard Alignment

The protocol is designed to align with emerging standards for content authenticity:

| Standard | Alignment |
|----------|-----------|
| **C2PA** | Custom assertion embedding (Section 12.6.1). |
| **Verifiable Credentials (W3C)** | The proof artifact can be wrapped as a Verifiable Credential with the author as the subject and the behavioral + World ID proofs as the credential claims. |
| **DID (Decentralized Identifiers)** | The `author_id` can be expressed as a DID: `did:akb:human_7Kx9mPqR3...`. A DID resolver would query the `.well-known` endpoint or on-chain registry. |
| **ActivityPub** | Federated social platforms (Mastodon, etc.) could include proof references in `Note` objects, enabling verified authorship in the Fediverse. |

---

*End of Sections 9-12. This specification is a living document. Contributions, corrections, and implementation feedback are welcome via the project's open-source repository.*

---


## 13. AT Protocol Integration

### 13.1 Overview

This section specifies how Speakwrite integrates with the AT Protocol (atproto) — the decentralized social networking protocol underlying Bluesky. The integration serves two purposes:

1. **Proof storage.** Speakwrite proof artifacts are stored as records in the author's AT Protocol data repository, alongside the posts they attest to. This leverages the protocol's existing cryptographic commit chain, content addressing, and decentralized hosting.

2. **Verification labeling.** A dedicated Speakwrite labeler service subscribes to the AT Protocol firehose, verifies proof artifacts as they appear, and emits signed labels that clients can display alongside verified posts.

The integration is designed to be **non-invasive**: it requires no changes to the core AT Protocol specifications, no modifications to existing Bluesky lexicons, and no cooperation from the Bluesky AppView. It operates entirely within the AT Protocol's extensibility mechanisms — custom record types and third-party labelers.

### 13.2 Architectural Fit

AT Protocol provides several properties that align naturally with Speakwrite:

| AT Protocol Property | Speakwrite Benefit |
|---|---|
| **Signed commits.** Every record in a user's repo is covered by the repo's commit signature chain. | Proof artifacts inherit the repo's integrity guarantees — they can't be tampered with without invalidating the commit. |
| **Content addressing.** Records are referenced by CID (content identifier), which is a hash of the record's CBOR encoding. | Strong refs to proof artifacts are tamper-evident by construction. |
| **Decentralized identity (DIDs).** Users are identified by DIDs that survive server migration. | Author identity is doubly anchored: DID (atproto) + nullifier hash (WorldID). |
| **Third-party labelers.** The labeling system allows independent services to attach metadata to any record. | Verification results can be displayed in any atproto client that subscribes to the labeler, without client modifications. |
| **Custom lexicons.** Any party can define new record types under their own namespace. | Speakwrite records are first-class atproto records, stored in the user's repo, synchronized via the relay network. |
| **Firehose.** All repo mutations are broadcast in real-time. | A verification service can verify proofs as they're published, providing near-real-time labeling. |
| **Open unions in embeds.** Post embeds support unknown types gracefully. | Future clients can render Speakwrite verification inline; current clients simply ignore the embed. |

### 13.3 Namespace

All Speakwrite lexicons live under the NSID namespace:

```
org.speakwrite.*
```

This assumes control of the domain `speakwrite.org`. The namespace hierarchy:

```
org.speakwrite.proof          # Proof artifact record
org.speakwrite.identity       # Identity certificate record
org.speakwrite.revocation     # Key revocation record
org.speakwrite.labeler        # Labeler-specific definitions
```

DNS TXT record for lexicon discoverability:

```
_lexicon.speakwrite.org  TXT  "did=did:plc:<speakwrite-schema-did>"
```

### 13.4 Lexicon Definitions

#### 13.4.1 Proof Record (`org.speakwrite.proof`)

This is the core record type. One proof record is created for each attested document. It stores the full Speakwrite proof artifact and links to the atproto post it attests to.

```json
{
  "lexicon": 1,
  "id": "org.speakwrite.proof",
  "description": "An Speakwrite proof of human keystroke origin for a document or post. Contains the full proof artifact binding behavioral evidence, cryptographic signatures, and WorldID personhood verification to a specific piece of content.",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "description": "A proof artifact attesting to the human keystroke origin of a linked post or document.",
      "record": {
        "type": "object",
        "required": [
          "subject",
          "proofArtifact",
          "verificationLevel",
          "createdAt"
        ],
        "properties": {

          "subject": {
            "type": "ref",
            "ref": "com.atproto.repo.strongRef",
            "description": "Strong reference (AT-URI + CID) to the post or record this proof attests to. The CID pins the proof to a specific version of the content — if the post is edited, the proof no longer applies to the new version."
          },

          "proofArtifact": {
            "type": "bytes",
            "maxLength": 65536,
            "description": "The complete Speakwrite proof artifact, CBOR-encoded per the Speakwrite Protocol Specification Section 8.5. This is the canonical binary form; the CID of this record provides content-addressing for the proof itself."
          },

          "documentHash": {
            "type": "string",
            "minLength": 64,
            "maxLength": 64,
            "description": "SHA-256 hash of the canonical document content (hex-encoded, lowercase). This is extracted from the proof artifact for indexing convenience. Verifiers MUST re-derive this from the proof artifact and confirm it matches."
          },

          "authorPubkey": {
            "type": "string",
            "minLength": 64,
            "maxLength": 64,
            "description": "The author's Ed25519 public key (hex-encoded) from the proof artifact. Extracted for indexing. Verifiers MUST confirm this matches the proof artifact's author_pubkey field."
          },

          "worldidNullifier": {
            "type": "string",
            "minLength": 64,
            "maxLength": 64,
            "description": "The WorldID nullifier hash from the proof artifact's publication proof (hex-encoded). This is the author's stable pseudonymous identifier across all Speakwrite publications. Extracted for cross-document queries."
          },

          "verificationLevel": {
            "type": "string",
            "knownValues": ["orb", "device"],
            "description": "The WorldID verification level achieved. 'orb' indicates biometric iris verification (highest assurance). 'device' indicates phone-based verification (lower assurance)."
          },

          "sessionDuration": {
            "type": "integer",
            "minimum": 0,
            "description": "Writing session duration in seconds. Extracted from the proof artifact for display purposes."
          },

          "totalKeystrokes": {
            "type": "integer",
            "minimum": 0,
            "description": "Total keystrokes recorded during the writing session. Extracted for display."
          },

          "windowCount": {
            "type": "integer",
            "minimum": 1,
            "description": "Number of behavioral observation windows in the commitment chain."
          },

          "identityCertificateRef": {
            "type": "ref",
            "ref": "com.atproto.repo.strongRef",
            "description": "Optional strong reference to the author's org.speakwrite.identity record in their repo. If present, verifiers can fetch the full identity certificate without an external registry lookup."
          },

          "createdAt": {
            "type": "string",
            "format": "datetime",
            "description": "Timestamp of proof record creation (ISO 8601)."
          }
        }
      }
    }
  }
}
```

**Record key:** TID (timestamp-based identifier). This ensures proofs are ordered chronologically and avoids key collisions.

**Size considerations:** The `proofArtifact` field (CBOR bytes) is typically 1.5-3 KB for a standard writing session. With the 65 KB limit, this comfortably accommodates sessions with hundreds of behavioral windows. The AT Protocol repo record size limit (currently ~1 MB per record including overhead) is not a concern.

**Why store the full artifact in bytes rather than as structured fields:** The proof artifact is a sealed, signed object. Decomposing it into atproto record fields would break the signature — the signature covers the canonical CBOR encoding of the artifact as specified in Section 8.3.4, Step 5. The CBOR blob preserves the exact bytes that were signed, enabling verification without re-canonicalization.

**Indexed fields:** The `documentHash`, `authorPubkey`, `worldidNullifier`, and `verificationLevel` fields are extracted from the proof artifact and stored as top-level fields for efficient querying by AppViews and feed generators. These are convenience duplicates — all verification MUST operate on the `proofArtifact` blob directly.

#### 13.4.2 Identity Certificate Record (`org.speakwrite.identity`)

Stores the author's Speakwrite identity certificate in their repo, providing a discoverable location for the WorldID-to-pubkey binding.

```json
{
  "lexicon": 1,
  "id": "org.speakwrite.identity",
  "description": "An Speakwrite identity certificate binding an Ed25519 public key to a WorldID proof of personhood. Published once per author (at rkey 'self') and updated on key rotation.",
  "defs": {
    "main": {
      "type": "record",
      "key": "literal:self",
      "description": "The author's Speakwrite identity certificate.",
      "record": {
        "type": "object",
        "required": [
          "certificate",
          "authorPubkey",
          "worldidNullifier",
          "verificationLevel",
          "createdAt"
        ],
        "properties": {

          "certificate": {
            "type": "bytes",
            "maxLength": 4096,
            "description": "The full IdentityCertificate (Section 7.3 of the Speakwrite spec), CBOR-encoded. Contains the Ed25519 pubkey, WorldID Groth16 proof, nullifier hash, Merkle root, verification level, and action metadata."
          },

          "authorPubkey": {
            "type": "string",
            "minLength": 64,
            "maxLength": 64,
            "description": "Ed25519 public key (hex). Extracted for indexing."
          },

          "worldidNullifier": {
            "type": "string",
            "minLength": 64,
            "maxLength": 64,
            "description": "WorldID nullifier hash (hex). The author's stable pseudonymous Speakwrite identity."
          },

          "verificationLevel": {
            "type": "string",
            "knownValues": ["orb", "device"],
            "description": "WorldID verification level."
          },

          "atprotoDid": {
            "type": "string",
            "format": "did",
            "description": "The author's AT Protocol DID. Including this creates a verifiable bidirectional link: the atproto repo (signed by the DID's key) contains this record which contains the Speakwrite pubkey, and the Speakwrite proofs are signed by that pubkey. This establishes: atproto identity <-> Speakwrite identity."
          },

          "createdAt": {
            "type": "string",
            "format": "datetime",
            "description": "Timestamp of certificate creation."
          }
        }
      }
    }
  }
}
```

**Record key:** Literal `self`. This is a singleton record — each author has exactly one identity certificate. On key rotation, this record is updated with the new certificate (the old certificate is preserved in the repo's commit history via the MST).

**Bidirectional identity binding:** The `atprotoDid` field creates a trust chain:
1. The atproto repo is signed by the DID's signing key → the repo is authoritative for this DID.
2. The repo contains an `org.speakwrite.identity/self` record → the DID holder claims this Speakwrite pubkey.
3. The identity certificate contains a WorldID proof binding the pubkey to a unique human → the pubkey is owned by a verified human.
4. Speakwrite proofs are signed by the pubkey → the proofs are by that human.

Therefore: **atproto DID → Speakwrite pubkey → WorldID unique human → proof artifacts**.

#### 13.4.3 Revocation Record (`org.speakwrite.revocation`)

```json
{
  "lexicon": 1,
  "id": "org.speakwrite.revocation",
  "description": "A key revocation record. Published when an author rotates or revokes their Speakwrite signing key.",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "description": "Revocation of an Speakwrite signing key.",
      "record": {
        "type": "object",
        "required": [
          "revocation",
          "revokedPubkey",
          "createdAt"
        ],
        "properties": {

          "revocation": {
            "type": "bytes",
            "maxLength": 4096,
            "description": "The SignedRevocation object (Section 7.4.1), CBOR-encoded. Contains the revocation message and Ed25519 signature by the revoked key."
          },

          "revokedPubkey": {
            "type": "string",
            "minLength": 64,
            "maxLength": 64,
            "description": "Ed25519 public key being revoked (hex). Extracted for indexing."
          },

          "successorPubkey": {
            "type": "string",
            "minLength": 64,
            "maxLength": 64,
            "description": "Ed25519 public key of the successor (hex). Null if the key is being permanently retired rather than rotated."
          },

          "reason": {
            "type": "string",
            "maxLength": 1000,
            "description": "Human-readable reason for revocation."
          },

          "createdAt": {
            "type": "string",
            "format": "datetime",
            "description": "Timestamp of revocation."
          }
        }
      }
    }
  }
}
```

### 13.5 Publishing Flow

When an author writes a post with Speakwrite instrumentation and publishes to Bluesky, the following sequence occurs:

```
┌─────────────────────────────────────────────────────────┐
│                     AUTHOR'S CLIENT                     │
│                                                         │
│  1. Author writes post in instrumented editor           │
│     (Speakwrite observer captures keystrokes)     │
│                                                         │
│  2. Author clicks "Publish"                             │
│     │                                                   │
│     ├── a. Finalize post text                           │
│     │                                                   │
│     ├── b. Compute document hash of canonical post text │
│     │                                                   │
│     ├── c. Finalize behavioral features                 │
│     │                                                   │
│     ├── d. WorldID verification (QR / World App)        │
│     │      signal = H(doc_hash ∥ pubkey ∥ beh_hash     │
│     │               ∥ commitment_root)                  │
│     │                                                   │
│     ├── e. Sign proof artifact with Ed25519 key         │
│     │                                                   │
│     ├── f. Create the Bluesky post record               │
│     │      (app.bsky.feed.post)                         │
│     │      → receives post AT-URI and CID               │
│     │                                                   │
│     └── g. Create the proof record                      │
│            (org.speakwrite.proof)                  │
│            with subject = strongRef(post URI, post CID) │
│                                                         │
│  Both records committed to repo in a single commit      │
│  or two sequential commits                              │
└─────────────────────┬───────────────────────────────────┘
                      │
                      │ Repo sync via AT Protocol relay
                      ▼
┌─────────────────────────────────────────────────────────┐
│                     RELAY / FIREHOSE                     │
│                                                         │
│  Broadcasts #commit events containing both records      │
│  to all subscribers                                     │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
          ┌───────────┴───────────┐
          │                       │
          ▼                       ▼
┌──────────────────┐   ┌──────────────────────────┐
│  BLUESKY APPVIEW │   │  AUTHENTIKEYBOARD        │
│                  │   │  LABELER SERVICE          │
│  Indexes the     │   │                          │
│  post as normal. │   │  1. Receives commit event│
│  Ignores the     │   │  2. Detects proof record │
│  proof record    │   │  3. Fetches linked post  │
│  (unknown NSID). │   │  4. Runs full            │
│                  │   │     verification          │
│                  │   │     (Section 8.4)         │
│                  │   │  5. Emits signed label    │
│                  │   │     on the post           │
└──────────────────┘   └──────────────────────────┘
```

**Atomic publish (ideal):** The client creates both the post and the proof in a single `com.atproto.repo.applyWrites` batch operation. This ensures they appear in the same commit, making the proof immediately discoverable.

```
com.atproto.repo.applyWrites({
  repo: author_did,
  writes: [
    {
      $type: "com.atproto.repo.applyWrites#create",
      collection: "app.bsky.feed.post",
      rkey: post_tid,
      value: { /* post record */ }
    },
    {
      $type: "com.atproto.repo.applyWrites#create",
      collection: "org.speakwrite.proof",
      rkey: proof_tid,
      value: { /* proof record with subject pointing to post */ }
    }
  ]
})
```

**Sequential publish (fallback):** If the PDS doesn't support `applyWrites` batches with cross-collection references, the client creates the post first, obtains its CID, then creates the proof record pointing to it. The proof record appears in a subsequent commit.

**Document hash computation for posts:** The canonical document for an `app.bsky.feed.post` record is derived as follows:

```
PROCEDURE CanonicalPostText(post_record):
  1. Extract the `text` field from the post record.
  2. Apply NFC Unicode normalization.
  3. Normalize line endings to U+000A.
  4. Strip trailing whitespace per line.
  5. Strip leading/trailing blank lines.
  6. Encode as UTF-8.
  7. Return SHA-256(utf8_bytes).
```

This matches the document hashing procedure in Section 6.2.1 of the main spec, applied to the post's text content.

**Important: The document hash covers only the text, not embeds, facets, or metadata.** This is intentional — the proof attests to what was *typed*, not to images, link cards, or mentions that were attached via UI interactions. If the post text is edited, the proof becomes invalid (CID mismatch in the strong ref). If only embeds or metadata change, the text hash remains valid but the strong ref CID will mismatch, correctly invalidating the proof.

### 13.6 Labeler Service

The Speakwrite labeler is a third-party atproto labeler service that verifies proof artifacts and attaches human-readable verification labels to posts.

#### 13.6.1 Labeler Identity

The labeler operates as a standard atproto account with:

- **DID:** `did:plc:<speakwrite-labeler-did>` (or `did:web:labeler.speakwrite.org`)
- **Handle:** `labeler.speakwrite.org`
- **DID document additions:**
  - Signing key with fragment `#atproto_label` (for signing labels)
  - Service endpoint with fragment `#atproto_labeler`, type `AtprotoLabeler`, pointing to the labeler's HTTPS endpoint

#### 13.6.2 Label Vocabulary

The labeler declares the following label values in its `app.bsky.labeler.service/self` record:

```json
{
  "$type": "app.bsky.labeler.service",
  "policies": {
    "labelValues": [
      "human-verified-strong",
      "human-verified-moderate",
      "human-verified-weak",
      "human-verified-anomaly",
      "human-verified-invalid"
    ],
    "labelValueDefinitions": [
      {
        "identifier": "human-verified-strong",
        "blurs": "none",
        "severity": "inform",
        "defaultSetting": "warn",
        "adultOnly": false,
        "locales": [
          {
            "lang": "en",
            "name": "Human Verified (Strong)",
            "description": "This post was typed by an orb-verified unique human with a consistent behavioral history. Verified by Speakwrite."
          }
        ]
      },
      {
        "identifier": "human-verified-moderate",
        "blurs": "none",
        "severity": "inform",
        "defaultSetting": "warn",
        "adultOnly": false,
        "locales": [
          {
            "lang": "en",
            "name": "Human Verified (Moderate)",
            "description": "This post was typed by a verified human. Either device-level verification or limited publication history. Verified by Speakwrite."
          }
        ]
      },
      {
        "identifier": "human-verified-weak",
        "blurs": "none",
        "severity": "inform",
        "defaultSetting": "warn",
        "adultOnly": false,
        "locales": [
          {
            "lang": "en",
            "name": "Human Verified (Weak)",
            "description": "This post has behavioral evidence of human typing, but personhood verification is incomplete. Verified by Speakwrite."
          }
        ]
      },
      {
        "identifier": "human-verified-anomaly",
        "blurs": "none",
        "severity": "inform",
        "defaultSetting": "warn",
        "adultOnly": false,
        "locales": [
          {
            "lang": "en",
            "name": "Verification Anomaly",
            "description": "This post has a human verification proof, but behavioral analysis flagged anomalies. The proof may be valid but unusual."
          }
        ]
      },
      {
        "identifier": "human-verified-invalid",
        "blurs": "none",
        "severity": "alert",
        "defaultSetting": "warn",
        "adultOnly": false,
        "locales": [
          {
            "lang": "en",
            "name": "Invalid Verification",
            "description": "This post has an Speakwrite proof that failed verification. The proof artifact may be forged, corrupted, or tampered with."
          }
        ]
      }
    ]
  },
  "createdAt": "2026-02-13T00:00:00.000Z"
}
```

**Label semantics:**

| Label Value | Maps To (Section 8.4.3) | Behavior |
|---|---|---|
| `human-verified-strong` | `VERIFIED_STRONG` (0x01) | Green badge. Orb-verified, no anomalies, consistent history. |
| `human-verified-moderate` | `VERIFIED_MODERATE` (0x02) | Blue badge. Device-verified, or no cross-document history. |
| `human-verified-weak` | `VERIFIED_WEAK` (0x03) | Gray badge. Behavioral data only, no WorldID proof. |
| `human-verified-anomaly` | `BEHAVIORAL_ANOMALY` (0x04) | Yellow badge. Crypto valid, behavioral flags. |
| `human-verified-invalid` | `INVALID` (0x05) or `TAMPERED` (0x06) | Red badge. Verification failed. |

**Blurs setting:** All labels use `"blurs": "none"` — Speakwrite labels are informational, not content warnings. They never hide content.

**Severity:** `"inform"` for positive/neutral labels, `"alert"` for `human-verified-invalid` (to draw attention to potentially fraudulent claims).

#### 13.6.3 Labeler Verification Pipeline

The labeler service runs continuously and processes events from the AT Protocol firehose.

```
┌─────────────────────────────────────────────────────────┐
│                  LABELER SERVICE                         │
│                                                         │
│  ┌──────────────────────────────────────┐               │
│  │  FIREHOSE CONSUMER                   │               │
│  │                                      │               │
│  │  Connects to relay via:              │               │
│  │  com.atproto.sync.subscribeRepos     │               │
│  │                                      │               │
│  │  Filters #commit events for ops      │               │
│  │  where path starts with:             │               │
│  │  "org.speakwrite.proof/"       │               │
│  │                                      │               │
│  │  On match: decode record from        │               │
│  │  CAR blocks, enqueue for             │               │
│  │  verification                        │               │
│  └──────────────┬───────────────────────┘               │
│                 │                                        │
│  ┌──────────────▼───────────────────────┐               │
│  │  VERIFICATION WORKER POOL            │               │
│  │                                      │               │
│  │  For each proof record:              │               │
│  │                                      │               │
│  │  1. Parse the proof record           │               │
│  │  2. Fetch the subject post via       │               │
│  │     com.atproto.repo.getRecord       │               │
│  │  3. Verify strong ref:               │               │
│  │     - Confirm the fetched post's CID │               │
│  │       matches subject.cid            │               │
│  │  4. Compute canonical post text hash │               │
│  │  5. Decode proofArtifact (CBOR)      │               │
│  │  6. Run full verification            │               │
│  │     (Section 8.4, Steps 1-9)         │               │
│  │  7. Determine verification level     │               │
│  │  8. Emit signed label                │               │
│  └──────────────┬───────────────────────┘               │
│                 │                                        │
│  ┌──────────────▼───────────────────────┐               │
│  │  LABEL EMITTER                       │               │
│  │                                      │               │
│  │  Creates a signed label:             │               │
│  │  {                                   │               │
│  │    ver: 1,                           │               │
│  │    src: labeler_did,                 │               │
│  │    uri: post_at_uri,                 │               │
│  │    cid: post_cid,                    │               │
│  │    val: "human-verified-strong",     │               │
│  │    neg: false,                       │               │
│  │    cts: "2026-02-13T10:30:00Z",      │               │
│  │    sig: <ecdsa_signature>            │               │
│  │  }                                   │               │
│  │                                      │               │
│  │  Distributes via:                    │               │
│  │  - subscribeLabels WebSocket         │               │
│  │  - queryLabels HTTP endpoint         │               │
│  └──────────────────────────────────────┘               │
│                                                         │
│  ┌──────────────────────────────────────┐               │
│  │  AUTHOR PROFILE INDEX                │               │
│  │                                      │               │
│  │  Maintains per-nullifier state:      │               │
│  │  - Author Behavioral Profile (ABP)   │               │
│  │  - Publication count                 │               │
│  │  - Cross-document consistency scores │               │
│  │  - Trust level                       │               │
│  │                                      │               │
│  │  Updated after each verification.    │               │
│  └──────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────┘
```

**Label target:** The label is attached to the **post** (the `app.bsky.feed.post` record), not to the proof record. This ensures that standard Bluesky clients can display the label alongside the post without knowing anything about Speakwrite records.

**CID pinning:** The label includes the post's CID, pinning it to the exact version of the post that was verified. If the post is edited (new CID), the label no longer applies. The labeler can detect edits (new commits updating the post record), re-verify if a new proof is published, and emit a new label.

**Label negation:** If a proof is later found to be invalid (e.g., key revocation with a timestamp before the proof), the labeler emits a negation label (`"neg": true`) for the original positive label, followed by a `human-verified-invalid` label.

#### 13.6.4 Cross-Document Consistency in the Labeler

The labeler maintains an internal database mapping WorldID nullifier hashes to Author Behavioral Profiles (ABPs, Section 5.5.2). This enables:

1. **Progressive trust:** Each new verified proof by the same nullifier updates the ABP and recalculates the trust level. The labeler may upgrade previous labels (e.g., `human-verified-moderate` → `human-verified-strong`) as the author's publication history grows.

2. **Anomaly detection:** If a new proof by a known nullifier has significantly different behavioral features (Section 5.5.6), the labeler flags it with `human-verified-anomaly` and records the deviation details.

3. **Consistency score in labels:** The labeler stores the consistency score internally but does not expose it directly in the label (atproto labels are simple key-value pairs). Clients that want detailed verification information query the proof record directly.

### 13.7 Feed Generator: Verified Human Feed

An Speakwrite feed generator provides a custom Bluesky timeline containing only posts with valid Speakwrite proofs.

#### 13.7.1 Feed Declaration

```json
{
  "$type": "app.bsky.feed.generator",
  "did": "did:web:feed.speakwrite.org",
  "displayName": "Human Written",
  "description": "Posts verified as typed by a real human through keystroke behavioral analysis and WorldID proof of personhood.",
  "avatar": { "$type": "blob", "ref": { "$link": "..." }, "mimeType": "image/png", "size": 12345 },
  "createdAt": "2026-02-13T00:00:00.000Z",
  "labels": {
    "$type": "com.atproto.label.defs#selfLabels",
    "values": []
  }
}
```

Published as `app.bsky.feed.generator/<rkey>` in the Speakwrite service account's repo.

#### 13.7.2 Feed Algorithm

The feed generator subscribes to the firehose and maintains an index of verified posts.

**Indexing logic:**

```
ON firehose #commit event:
  FOR EACH op IN event.ops:
    IF op.path starts with "org.speakwrite.proof/":
      IF op.action == "create":
        Decode the proof record from the commit's CAR blocks.
        Extract subject (post AT-URI + CID).
        Store in the verified_posts index:
          {
            post_uri,
            post_cid,
            proof_uri,
            author_did: event.repo,
            worldid_nullifier,
            verification_level,
            session_duration,
            indexed_at: now()
          }
```

**Feed skeleton generation:**

```
ON getFeedSkeleton request (feed, cursor, limit):
  Query verified_posts index:
    ORDER BY indexed_at DESC
    WHERE verification_level IN ("orb", "device")
    LIMIT = request.limit
    CURSOR = parse(request.cursor)  // opaque token encoding indexed_at + post_uri

  Return skeleton:
    {
      cursor: encode(last_item.indexed_at, last_item.post_uri),
      feed: [
        { post: item.post_uri }
        for item in results
      ]
    }
```

**Feed variants:** Multiple feed generators can be registered under different rkeys:

| Feed | Criteria |
|---|---|
| `human-written` | All posts with `VERIFIED_STRONG` or `VERIFIED_MODERATE` |
| `human-written-orb` | Only orb-verified posts |
| `human-written-established` | Only posts by authors with Trust ≥ 0.78 (E ≥ 5 documents) |
| `human-written-long` | Verified posts with > 280 characters (long-form content) |

### 13.8 Client Integration

#### 13.8.1 Client Display of Labels

Any Bluesky client that subscribes to the Speakwrite labeler DID will automatically receive verification labels on posts. The client renders these labels according to its own UI conventions — typically as badges or information bars.

**No client modification required for basic display.** The atproto labeling system is designed for this: third-party labelers emit labels, clients opt in to labelers, and the AppView hydrates labels into API responses.

**Opt-in:** Users subscribe to the Speakwrite labeler by adding `did:plc:<speakwrite-labeler-did>` to their labeler preferences. This is a standard Bluesky client operation.

#### 13.8.2 Enhanced Client Integration

Clients that understand Speakwrite lexicons can provide richer integration:

1. **Proof detail view.** When a post has an Speakwrite label, the client can fetch the `org.speakwrite.proof` record from the author's repo and display detailed verification information:
   - Session duration, keystroke count, revision rate
   - Behavioral plausibility score
   - WorldID verification level
   - Cross-document consistency (via labeler API or direct computation)

2. **Author verification badge.** The client can fetch `org.speakwrite.identity/self` from the author's repo to display a persistent "Verified Human" badge on the author's profile.

3. **Verification on hover/click.** The client can perform independent client-side verification of the proof artifact (the same verification the web widget performs in Section 9), providing zero-trust verification without relying on the labeler.

#### 13.8.3 Writing Client: Instrumented Composer

The richest integration is a Bluesky client with a built-in Speakwrite observer in the post composer. This is the equivalent of the standalone editor (Section 11) but embedded in a social client.

```
┌─────────────────────────────────────────┐
│         Bluesky Client with             │
│         Speakwrite Composer        │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │   [Post Composer]                 │  │
│  │                                   │  │
│  │   What's on your mind?            │  │
│  │   ┌─────────────────────────────┐ │  │
│  │   │ The thing about distributed │ │  │
│  │   │ systems is that they force  │ │  │
│  │   │ you to think about failure  │ │  │
│  │   │ modes that centralized      │ │  │
│  │   │ systems pretend don't exist │ │  │
│  │   └─────────────────────────────┘ │  │
│  │                                   │  │
│  │   [🔒 Speakwrite Active]    │  │
│  │   72 seconds | 312 keystrokes     │  │
│  │   4.8% revision rate              │  │
│  │                                   │  │
│  │   [Post]  [Post + Verify ✓]       │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  "Post + Verify" triggers:              │
│    1. Standard post creation            │
│    2. WorldID verification prompt       │
│    3. Proof artifact creation           │
│    4. Proof record publication          │
│                                         │
└─────────────────────────────────────────┘
```

**The composer offers two publish buttons:**
- **Post** — standard post, no proof (for when the author doesn't need verification, e.g., casual replies).
- **Post + Verify** — creates the post with a linked Speakwrite proof. Triggers the WorldID verification flow.

This is the primary adoption surface. Most users won't use a standalone writing environment for social posts — they'll use their Bluesky client directly.

### 13.9 Discovery and Resolution

#### 13.9.1 Finding a Post's Proof

Given a post AT-URI, a client or service discovers the associated proof via:

**Method 1: Repo scan (authoritative).** List records in the author's repo under the `org.speakwrite.proof` collection. For each proof record, check if the `subject.uri` matches the post URI and `subject.cid` matches the post CID.

```
com.atproto.repo.listRecords({
  repo: author_did,
  collection: "org.speakwrite.proof",
  limit: 100
})
// Filter results where subject.uri == post_uri
```

**Method 2: Labeler query (fast, but trust-dependent).** Query the Speakwrite labeler's `com.atproto.label.queryLabels` endpoint with the post URI as the subject. If a label exists, the post has been verified. The label itself doesn't contain the proof, but confirms verification has occurred.

**Method 3: AppView index (fastest, if available).** If an Speakwrite AppView exists, it maintains a post→proof index and exposes a query endpoint.

#### 13.9.2 Finding an Author's Identity

Given an atproto DID, fetch:

```
com.atproto.repo.getRecord({
  repo: author_did,
  collection: "org.speakwrite.identity",
  rkey: "self"
})
```

If the record exists, the author has an Speakwrite identity. The `worldidNullifier` field is their stable Speakwrite pseudonym.

#### 13.9.3 Finding All Posts by a Verified Human

Given a WorldID nullifier hash, the labeler or AppView can return all posts by that author:

1. Query the internal index for all proof records with matching `worldidNullifier`.
2. Return the associated post URIs.

This enables a "View all verified posts by this human" feature without revealing who the human is.

### 13.10 Security Considerations for AT Protocol Integration

#### 13.10.1 Repo Signature vs. Speakwrite Signature

Every record in an atproto repo is covered by the repo's commit signature (signed by the DID's signing key). The Speakwrite proof artifact has its *own* Ed25519 signature (signed by the Speakwrite identity key). These are independent:

- The **repo signature** proves the record was committed by the account holder.
- The **Speakwrite signature** proves the proof artifact was created by the Speakwrite identity holder.

Both are necessary:
- The repo signature prevents someone from *injecting* a proof into another user's repo.
- The Speakwrite signature prevents someone from *fabricating* a proof artifact (even the account holder can't forge a valid WorldID proof or behavioral attestation without the actual writing process).

#### 13.10.2 Post Mutability

AT Protocol posts can be edited (updated in place, producing a new CID). The proof record's `subject` field includes the post's CID via strong ref. If the post is edited:

1. The strong ref CID no longer matches the current post CID.
2. The document hash in the proof artifact no longer matches the new post text.
3. The label (pinned to the old CID) no longer applies.

**This is correct behavior.** An edit invalidates the proof because the edited text was not verified. To re-verify, the author must create a new proof for the edited version.

**Label lifecycle on edit:**
1. Labeler detects post update via firehose.
2. Labeler negates the existing label (emits `neg: true`).
3. If a new proof record appears for the updated post (new CID), the labeler verifies and emits a new label.

#### 13.10.3 Post Deletion

If a post is deleted, the associated proof record becomes an orphan (its `subject` points to a non-existent record). The labeler detects the deletion and negates any labels. The proof record itself should be deleted by the author (or can remain as a historical artifact — it proves that *some* document was verified, even if the document is no longer available).

#### 13.10.4 Labeler Trust Model

The labeler is a trusted intermediary for *label generation* but not for *verification*. Any client can independently:

1. Fetch the proof record from the author's repo.
2. Fetch the linked post.
3. Run full Speakwrite verification (Section 8.4) locally.

The labeler exists for convenience (so standard clients can show badges without implementing a Groth16 verifier), but the protocol's security does not depend on the labeler's honesty. A dishonest labeler could:

- **Emit false positives** (label an unverified post as verified) — detectable by any independent verifier.
- **Emit false negatives** (refuse to label a verified post) — detectable by independent verification; the proof record in the repo serves as ground truth.
- **Emit stale labels** — detectable by comparing the label's CID with the post's current CID.

**Multiple labelers can coexist.** Different organizations can run their own Speakwrite labeler services with different verification policies (e.g., stricter behavioral thresholds, different minimum trust levels). Users choose which labelers to subscribe to.

#### 13.10.5 Firehose Processing Requirements

The AT Protocol firehose delivers approximately 50-500 events per second (varying with network activity). Of these, only a small fraction will be `org.speakwrite.proof` records. The labeler must:

- Process the full firehose efficiently (filter by collection NSID in the `ops` array).
- Handle backpressure: buffer proof records during verification spikes.
- Maintain cursor state for reconnection.
- Verify proofs within a reasonable latency target (< 30 seconds from commit to label emission).

**Groth16 verification cost:** BN254 pairing operations are computationally expensive. On modern hardware, a single Groth16 verification takes approximately 5-15 ms. With two WorldID proofs per Speakwrite proof (binding + publication), verification time is approximately 10-30 ms per proof. At expected volumes (hundreds to low thousands of proofs per day initially), this is not a bottleneck. At scale, a worker pool can parallelize verification.

### 13.11 Implementation Checklist

For a minimum viable AT Protocol integration:

**Phase 1: Records and Identity**
- [ ] Define and publish lexicon schemas for `org.speakwrite.proof`, `.identity`, `.revocation`
- [ ] Implement proof record creation in the Speakwrite client SDK
- [ ] Implement `applyWrites` batch publish (post + proof in one commit)
- [ ] Implement identity certificate publication (`identity/self`)
- [ ] Set up DNS TXT for lexicon discoverability

**Phase 2: Labeler Service**
- [ ] Create labeler atproto account
- [ ] Set up DID document with `#atproto_label` key and `#atproto_labeler` service
- [ ] Publish `app.bsky.labeler.service/self` with label vocabulary
- [ ] Implement firehose consumer (filter for `org.speakwrite.proof` ops)
- [ ] Implement verification worker pool
- [ ] Implement label signing and emission
- [ ] Implement `com.atproto.label.subscribeLabels` WebSocket endpoint
- [ ] Implement `com.atproto.label.queryLabels` HTTP endpoint
- [ ] Implement author profile index (nullifier → ABP)

**Phase 3: Feed Generator**
- [ ] Create feed generator service DID
- [ ] Publish `app.bsky.feed.generator` records for feed variants
- [ ] Implement verified post index
- [ ] Implement `getFeedSkeleton` endpoint

**Phase 4: Client Integration**
- [ ] Build instrumented post composer (browser extension or standalone client)
- [ ] Implement "Post + Verify" flow with WorldID integration
- [ ] Build proof detail view component
- [ ] Build author verification badge component

---

*End of Section 13: AT Protocol Integration.*

---

## 14. Desktop Application Architecture

### 14.1 Overview

This section specifies the architecture of the Speakwrite desktop application — a local-first text editor that implements the full Speakwrite protocol. The application captures keystroke dynamics during composition, generates proof artifacts locally, and publishes verified content to external platforms.

The desktop application is the **reference implementation** of the Speakwrite Observer (Section 4), Feature Extraction Engine (Section 5), and Signing Protocol (Section 8). It is the canonical environment in which the full protocol operates end-to-end.

#### 14.1.1 Why a Desktop Application

The decision to implement Speakwrite as a standalone desktop application — rather than a browser extension, web application, or plugin for an existing editor — is driven by three architectural requirements:

1. **Privacy by architecture.** Raw keystroke biometric data (Section 4.2) never leaves the author's device. There is no server, no cloud sync of behavioral data, and no network request during the capture phase. The application's process boundary *is* the privacy boundary. This eliminates entire categories of compliance concerns (GDPR Article 9 special categories, BIPA biometric data collection, CCPA biometric identifiers) because the data controller and the data subject are the same entity.

2. **Observer integrity.** The threat model (Section 3) identifies observer compromise as a critical attack vector. A desktop application running as a native process provides stronger isolation guarantees than a browser extension (which shares a process with arbitrary web content) or a web application (which is served by a party that could modify it silently). Users can build the application from source, verify its signature, and audit its behavior.

3. **Cryptographic safety.** Private key material (Section 7.1) and ephemeral keystroke data must be handled with care. A native application can use OS-level keychain integration, memory-safe cryptographic implementations in Rust, and process-level memory protections that are not available to JavaScript running in a browser sandbox.

#### 14.1.2 Technology Selection: Tauri

The application is built on **Tauri 2.x** — a framework for building desktop applications with a Rust backend and web-technology frontend rendered in the operating system's native WebView.

| Criterion | Tauri | Electron | Native (SwiftUI/GTK/WinUI) |
|-----------|-------|----------|---------------------------|
| Binary size | ~10-30 MB | ~150-300 MB | ~5-15 MB |
| Runtime | OS WebView + Rust | Bundled Chromium + Node.js | Native only |
| Memory usage | ~50-100 MB | ~200-500 MB | ~30-80 MB |
| Crypto implementation | Rust (ed25519-dalek, sha2) | Node.js (noble-ed25519) or native addon | Platform-specific |
| Cross-platform | macOS, Linux, Windows | macOS, Linux, Windows | Separate codebases |
| Rich text editor | TipTap/ProseMirror in WebView | TipTap/ProseMirror in Chromium | Custom (significant effort) |
| IPC overhead | ~0.01-0.05 ms per invoke | ~0.1-0.5 ms per IPC | N/A |
| Open source trust | Auditable Rust core + web UI | Auditable but large surface | Auditable |

Tauri is selected because it provides the optimal trade-off: the rich text editing capabilities of web technology (TipTap/ProseMirror) combined with the memory safety and performance of Rust for cryptographic and behavioral analysis operations. The OS-native WebView avoids bundling an entire browser engine, keeping the binary small and the attack surface minimal.

#### 14.1.3 Process Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Tauri Application                     │
│                                                         │
│  ┌─────────────────────┐    ┌────────────────────────┐  │
│  │    Rust Core         │    │     WebView (OS)       │  │
│  │                     │    │                        │  │
│  │  ┌───────────────┐  │    │  ┌──────────────────┐  │  │
│  │  │ Crypto Module  │  │◄──►│  │ TipTap Editor    │  │  │
│  │  │ (ed25519,sha2) │  │IPC │  │ (ProseMirror)    │  │  │
│  │  └───────────────┘  │    │  └──────────────────┘  │  │
│  │  ┌───────────────┐  │    │  ┌──────────────────┐  │  │
│  │  │ Capture Buffer │  │◄──►│  │ Keystroke        │  │  │
│  │  │ (ephemeral)    │  │    │  │ Observer Ext.    │  │  │
│  │  └───────────────┘  │    │  └──────────────────┘  │  │
│  │  ┌───────────────┐  │    │  ┌──────────────────┐  │  │
│  │  │ Feature Engine │  │───►│  │ Proof Status UI  │  │  │
│  │  │ (6-tier)       │  │evt │  │ (sidebar)        │  │  │
│  │  └───────────────┘  │    │  └──────────────────┘  │  │
│  │  ┌───────────────┐  │    │  ┌──────────────────┐  │  │
│  │  │ SQLite Storage │  │    │  │ Publish Dialog   │  │  │
│  │  │ (rusqlite)     │  │    │  │ (WorldID+export) │  │  │
│  │  └───────────────┘  │    │  └──────────────────┘  │  │
│  │  ┌───────────────┐  │    │                        │  │
│  │  │ Proof Builder  │  │    │                        │  │
│  │  │ (Section 8)    │  │    │                        │  │
│  │  └───────────────┘  │    │                        │  │
│  └─────────────────────┘    └────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

The application consists of two processes:

1. **Rust core process.** The main application process, responsible for all cryptographic operations, keystroke buffering, feature extraction, proof generation, storage, and network communication (at publish time only). This process owns all sensitive data.

2. **WebView process.** The OS-native WebView (WKWebView on macOS, WebView2 on Windows, WebKitGTK on Linux) renders the editor UI. It runs the TipTap/ProseMirror editor, the keystroke observer extension, and the proof status display. It communicates with the Rust core exclusively through Tauri's IPC invoke mechanism.

**Critical invariant:** No raw keystroke timing data, private key material, or behavioral feature vectors are stored in the WebView's JavaScript memory beyond the minimum needed for a single IPC invoke call. The WebView is treated as an untrusted input source — it provides raw events, the Rust core validates and processes them.

---

### 14.2 Rust Core Architecture

The Rust core is organized as a library crate (`speakwrite-core`) with six modules, plus a Tauri application crate (`speakwrite-app`) that exposes the modules as IPC commands.

#### 14.2.1 Module Layout

```
src-tauri/
├── Cargo.toml
├── src/
│   ├── main.rs                    # Tauri application entry point
│   ├── commands/                  # Tauri IPC command handlers
│   │   ├── mod.rs
│   │   ├── capture.rs             # Keystroke recording commands
│   │   ├── session.rs             # Session lifecycle commands
│   │   ├── proof.rs               # Proof generation commands
│   │   ├── identity.rs            # Key management commands
│   │   ├── publish.rs             # Export and publish commands
│   │   └── query.rs               # Data query commands
│   └── lib.rs                     # Re-exports core library
├── core/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── crypto/
│       │   ├── mod.rs
│       │   ├── signing.rs         # Ed25519 signing (Section 6.2)
│       │   ├── hashing.rs         # SHA-256, domain separation (Section 6.1)
│       │   ├── commitments.rs     # Hash-based commitments (Section 6.3)
│       │   ├── merkle.rs          # Merkle tree construction (Section 6.4)
│       │   ├── key_storage.rs     # Argon2id encryption (Section 7.1.2)
│       │   └── cbor.rs            # Canonical CBOR encoding (Section 6.6)
│       ├── capture/
│       │   ├── mod.rs
│       │   ├── event_types.rs     # KeystrokeEvent, InputEvent, etc. (Section 4.1)
│       │   ├── buffer.rs          # Ephemeral ring buffer
│       │   ├── validator.rs       # Event validation and sanitization
│       │   └── session.rs         # Session state machine (Section 4.3)
│       ├── features/
│       │   ├── mod.rs
│       │   ├── tier1_temporal.rs   # Digraph/trigraph matrices (Section 5.1.1)
│       │   ├── tier2_errors.rs     # Error/revision patterns (Section 5.1.2)
│       │   ├── tier3_composition.rs # Burst/pause dynamics (Section 5.1.3)
│       │   ├── tier4_navigation.rs  # Cursor/selection patterns (Section 5.1.4)
│       │   ├── tier5_linguistic.rs  # Word/sentence timing (Section 5.1.5)
│       │   ├── tier6_session.rs     # Session macro-structure (Section 5.1.6)
│       │   ├── vector.rs           # FeatureVector struct (Section 5.2)
│       │   ├── windowing.rs        # Windowed extraction (Section 5.3)
│       │   ├── baseline.rs         # Human baseline model (Section 5.4)
│       │   └── consistency.rs      # Cross-document consistency (Section 5.5)
│       ├── proof/
│       │   ├── mod.rs
│       │   ├── artifact.rs         # ProofArtifact construction (Section 8.5)
│       │   ├── entanglement.rs     # Content-behavior segment_map (Section 8.4)
│       │   ├── chain.rs            # Incremental commitment chain (Section 8.3)
│       │   └── verification.rs     # Self-verification (Section 8.6)
│       ├── storage/
│       │   ├── mod.rs
│       │   ├── database.rs         # SQLite connection management
│       │   ├── migrations.rs       # Schema migrations
│       │   ├── models.rs           # ORM-like data structures
│       │   └── queries.rs          # Prepared statements
│       ├── identity/
│       │   ├── mod.rs
│       │   ├── keypair.rs          # Key generation and management (Section 7.1)
│       │   ├── worldid.rs          # WorldID bridge (Section 7.2)
│       │   ├── certificate.rs      # Identity certificate (Section 7.3)
│       │   └── rotation.rs         # Key rotation protocol (Section 7.1.4)
│       └── export/
│           ├── mod.rs
│           ├── atproto.rs          # AT Protocol publishing (Section 13)
│           ├── markdown.rs         # Signed markdown export
│           ├── proof_json.rs       # Standalone proof JSON export
│           └── widget.rs           # Embeddable HTML widget (Section 9)
```

#### 14.2.2 Crate Dependencies

```toml
[dependencies]
# Cryptography
ed25519-dalek = { version = "2.1", features = ["rand_core", "serde"] }
sha2 = "0.10"
argon2 = "0.5"
rand = "0.8"
rand_chacha = "0.3"
ciborium = "0.2"              # CBOR encoding (RFC 8949)
bip39 = "2.0"                 # Mnemonic backup (Section 7.1.3)

# Storage
rusqlite = { version = "0.31", features = ["bundled", "serde_json"] }

# Serialization
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_cbor = "0.11"

# AT Protocol
atrium-api = "0.24"           # AT Protocol client
atrium-xrpc-client = "0.5"

# Async runtime
tokio = { version = "1.0", features = ["rt", "macros"] }

# Time
chrono = { version = "0.4", features = ["serde"] }

# Statistics
statrs = "0.17"               # Statistical distributions
nalgebra = "0.33"              # Linear algebra (Mahalanobis distance)
```

#### 14.2.3 Crypto Module

The crypto module implements the cryptographic primitives specified in Section 6. All cryptographic operations execute in the Rust process — no cryptographic material crosses the IPC boundary in plaintext.

**Ed25519 Signing (Section 6.2):**

```rust
use ed25519_dalek::{SigningKey, VerifyingKey, Signature, Signer, Verifier};

pub struct AuthorKeyPair {
    signing_key: SigningKey,
    verifying_key: VerifyingKey,
}

impl AuthorKeyPair {
    /// Generate a new Ed25519 keypair from OS CSPRNG.
    pub fn generate() -> Self {
        let mut csprng = rand::rngs::OsRng;
        let signing_key = SigningKey::generate(&mut csprng);
        let verifying_key = signing_key.verifying_key();
        Self { signing_key, verifying_key }
    }

    /// Sign arbitrary data. Returns a 64-byte Ed25519 signature.
    pub fn sign(&self, message: &[u8]) -> Signature {
        self.signing_key.sign(message)
    }

    /// Export the public key as a 32-byte array.
    pub fn public_key_bytes(&self) -> [u8; 32] {
        self.verifying_key.to_bytes()
    }

    /// Serialize the private key encrypted with Argon2id.
    pub fn export_encrypted(&self, passphrase: &str) -> EncryptedKeyBundle {
        key_storage::encrypt_key(&self.signing_key, passphrase)
    }
}
```

**Argon2id Key Encryption (Section 7.1.2):**

```rust
use argon2::{Argon2, Algorithm, Version, Params};

pub struct EncryptedKeyBundle {
    pub salt: [u8; 32],
    pub nonce: [u8; 24],
    pub ciphertext: Vec<u8>,    // XChaCha20-Poly1305 encrypted signing key
    pub argon2_params: Argon2Params,
}

pub struct Argon2Params {
    pub m_cost: u32,    // 65536 (64 MiB)
    pub t_cost: u32,    // 3 iterations
    pub p_cost: u32,    // 4 lanes
}

pub fn encrypt_key(signing_key: &SigningKey, passphrase: &str) -> EncryptedKeyBundle {
    let salt = rand::random::<[u8; 32]>();
    let params = Params::new(65536, 3, 4, Some(32)).unwrap();
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

    let mut derived_key = [0u8; 32];
    argon2.hash_password_into(passphrase.as_bytes(), &salt, &mut derived_key).unwrap();

    // XChaCha20-Poly1305 encryption of the 32-byte signing key
    let nonce = rand::random::<[u8; 24]>();
    let ciphertext = xchacha20poly1305_encrypt(&derived_key, &nonce, &signing_key.to_bytes());

    EncryptedKeyBundle {
        salt,
        nonce,
        ciphertext,
        argon2_params: Argon2Params { m_cost: 65536, t_cost: 3, p_cost: 4 },
    }
}
```

**Incremental Commitment Chain (Section 8.3):**

```rust
use sha2::{Sha256, Digest};

pub struct CommitmentChain {
    entries: Vec<CommitmentEntry>,
}

pub struct CommitmentEntry {
    pub sequence: u32,
    pub commitment: [u8; 32],
    pub previous: Option<[u8; 32]>,
    pub timestamp: i64,
    pub nonce: [u8; 32],
}

impl CommitmentChain {
    pub fn new() -> Self {
        Self { entries: Vec::new() }
    }

    /// Add a new commitment to the chain.
    /// C_i = SHA-256(C_{i-1} || nonce_i || CBOR(feature_vector_i))
    pub fn commit(&mut self, feature_vector: &FeatureVector) -> CommitmentEntry {
        let nonce: [u8; 32] = rand::random();
        let previous = self.entries.last().map(|e| e.commitment);

        let mut hasher = Sha256::new();
        if let Some(prev) = previous {
            hasher.update(prev);
        }
        hasher.update(nonce);
        hasher.update(&canonical_cbor_encode(feature_vector));

        let commitment: [u8; 32] = hasher.finalize().into();
        let entry = CommitmentEntry {
            sequence: self.entries.len() as u32,
            commitment,
            previous,
            timestamp: chrono::Utc::now().timestamp_millis(),
            nonce,
        };

        self.entries.push(entry.clone());
        entry
    }
}
```

#### 14.2.4 Capture Module

The capture module receives raw keystroke events from the frontend via IPC, validates them, stores them in an ephemeral ring buffer, and manages session lifecycle.

**Event Types (Section 4.1):**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeystrokeEvent {
    pub event_type: KeyEventType,
    pub key: String,
    pub code: String,
    pub timestamp: f64,           // DOMHighResTimeStamp (ms, sub-ms precision)
    pub shift_key: bool,
    pub ctrl_key: bool,
    pub alt_key: bool,
    pub meta_key: bool,
    pub repeat: bool,
    pub is_composing: bool,
    pub sequence_number: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum KeyEventType {
    KeyDown,
    KeyUp,
    Input,
    CompositionStart,
    CompositionUpdate,
    CompositionEnd,
    SelectionChange,
    Paste,
    Cut,
}
```

**Ephemeral Ring Buffer:**

```rust
pub struct EphemeralBuffer {
    events: VecDeque<KeystrokeEvent>,
    max_size: usize,              // Default: 100,000 events
    session_id: SessionId,
}

impl EphemeralBuffer {
    /// Insert a validated event. O(1) amortized.
    pub fn push(&mut self, event: KeystrokeEvent) {
        if self.events.len() >= self.max_size {
            // Trigger emergency feature extraction before eviction
            self.flush_oldest_window();
        }
        self.events.push_back(event);
    }

    /// Extract and consume events for a time window.
    /// Events are DESTROYED after extraction (Section 4.2 ephemeral zone).
    pub fn drain_window(&mut self, start: f64, end: f64) -> Vec<KeystrokeEvent> {
        let mut window_events = Vec::new();
        self.events.retain(|e| {
            if e.timestamp >= start && e.timestamp < end {
                window_events.push(e.clone());
                false  // Remove from buffer
            } else {
                true   // Keep in buffer
            }
        });
        window_events
    }
}
```

**Event Validation:**

All events received from the WebView are validated before storage:

```rust
pub fn validate_event(event: &KeystrokeEvent, session: &SessionState) -> Result<(), ValidationError> {
    // 1. Sequence number must be monotonically increasing
    if event.sequence_number <= session.last_sequence_number {
        return Err(ValidationError::SequenceRegression);
    }

    // 2. Timestamp must be monotonically non-decreasing
    if event.timestamp < session.last_timestamp {
        return Err(ValidationError::TimestampRegression);
    }

    // 3. Timestamp must not be in the future (with 100ms tolerance for clock skew)
    let now = performance_now();
    if event.timestamp > now + 100.0 {
        return Err(ValidationError::FutureTimestamp);
    }

    // 4. Key code must be a known value
    if !is_valid_key_code(&event.code) {
        return Err(ValidationError::UnknownKeyCode);
    }

    // 5. Repeat events for non-repeatable keys are suspicious
    if event.repeat && !is_repeatable_key(&event.code) {
        return Err(ValidationError::InvalidRepeat);
    }

    Ok(())
}
```

#### 14.2.5 Feature Extraction Module

The feature extraction module implements the six-tier feature taxonomy (Section 5.1) and the windowed extraction pipeline (Section 5.3).

**Windowed Extraction Pipeline:**

```rust
pub struct ExtractionEngine {
    window_duration: f64,         // 300,000 ms (5 minutes)
    window_stride: f64,           // 60,000 ms (1 minute)
    current_window_start: f64,
    accumulated_vectors: Vec<WindowFeatureVector>,
}

impl ExtractionEngine {
    /// Process a completed window of events into a FeatureVector.
    pub fn extract_window(&mut self, events: &[KeystrokeEvent]) -> WindowFeatureVector {
        let tier1 = tier1_temporal::extract(events);
        let tier2 = tier2_errors::extract(events);
        let tier3 = tier3_composition::extract(events);
        let tier4 = tier4_navigation::extract(events);
        let tier5 = tier5_linguistic::extract(events);
        let tier6 = tier6_session::extract(events);

        WindowFeatureVector {
            window_start: events.first().map(|e| e.timestamp).unwrap_or(0.0),
            window_end: events.last().map(|e| e.timestamp).unwrap_or(0.0),
            keystroke_count: events.len() as u32,
            tier1,
            tier2,
            tier3,
            tier4,
            tier5,
            tier6,
        }
    }

    /// Aggregate all window vectors into a session-level FeatureVector.
    /// Uses weighted averaging per Section 5.3.4.
    pub fn aggregate_session(&self) -> FeatureVector {
        let weights: Vec<f64> = self.accumulated_vectors.iter()
            .map(|w| w.keystroke_count as f64)
            .collect();
        let total_weight: f64 = weights.iter().sum();

        // Weighted mean for each scalar feature
        // Merged distributions for digraph/trigraph matrices
        aggregate_weighted(&self.accumulated_vectors, &weights, total_weight)
    }
}
```

**Tier 1 Temporal Microstructure (Section 5.1.1):**

```rust
pub struct Tier1Features {
    pub flight_time_mean: f64,
    pub flight_time_std: f64,
    pub flight_time_median: f64,
    pub flight_time_skewness: f64,
    pub hold_time_mean: f64,
    pub hold_time_std: f64,
    pub digraph_matrix: HashMap<(char, char), DigraphStats>,
    pub trigraph_top200: Vec<TrigraphEntry>,
    pub overlap_ratio: f64,
    pub mean_overlap_duration: f64,
}

pub struct DigraphStats {
    pub count: u32,
    pub mean: f64,
    pub std_dev: f64,
    pub median: f64,
    pub skewness: f64,
    pub p10: f64,
    pub p90: f64,
}

pub fn extract(events: &[KeystrokeEvent]) -> Tier1Features {
    let keydowns: Vec<&KeystrokeEvent> = events.iter()
        .filter(|e| matches!(e.event_type, KeyEventType::KeyDown) && !e.repeat)
        .collect();

    // Compute flight times between consecutive keydowns
    let flight_times: Vec<f64> = keydowns.windows(2)
        .map(|pair| pair[1].timestamp - pair[0].timestamp)
        .filter(|&ft| ft > 0.0 && ft <= 30_000.0)  // T_pause_max
        .collect();

    // Build digraph matrix
    let mut digraph_map: HashMap<(char, char), Vec<f64>> = HashMap::new();
    for pair in keydowns.windows(2) {
        let c1 = key_to_char(&pair[0].key);
        let c2 = key_to_char(&pair[1].key);
        let ft = pair[1].timestamp - pair[0].timestamp;
        if ft > 0.0 && ft <= 30_000.0 {
            digraph_map.entry((c1, c2)).or_default().push(ft);
        }
    }

    // Compute statistics for digraphs with k_min >= 5 observations
    let digraph_matrix: HashMap<(char, char), DigraphStats> = digraph_map.into_iter()
        .filter(|(_, times)| times.len() >= 5)
        .map(|(pair, times)| (pair, compute_digraph_stats(&times)))
        .collect();

    // ... hold times, trigraphs, overlap detection ...
    Tier1Features { /* ... */ }
}
```

#### 14.2.6 Storage Module

The storage module manages a local SQLite database for all persistent data.

**Database Location:**

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/org.speakwrite.app/data.db` |
| Linux | `~/.local/share/org.speakwrite.app/data.db` |
| Windows | `%APPDATA%\org.speakwrite.app\data.db` |

**Schema Definition:**

```sql
-- Documents: metadata for each document authored in the editor
CREATE TABLE documents (
    id TEXT PRIMARY KEY,                    -- UUID v4
    title TEXT NOT NULL DEFAULT 'Untitled',
    content_hash TEXT,                      -- SHA-256 of final content (hex)
    content_format TEXT NOT NULL DEFAULT 'prosemirror',  -- 'prosemirror' | 'markdown'
    word_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,               -- ISO 8601
    updated_at TEXT NOT NULL,               -- ISO 8601
    published_at TEXT,                      -- ISO 8601, NULL if unpublished
    published_to TEXT                       -- 'atproto' | 'markdown' | 'widget' | NULL
);

-- Sessions: one or more writing sessions per document
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,                    -- UUID v4
    document_id TEXT NOT NULL REFERENCES documents(id),
    started_at TEXT NOT NULL,               -- ISO 8601
    ended_at TEXT,                          -- ISO 8601, NULL if active
    keystroke_count INTEGER DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',  -- 'active' | 'paused' | 'completed' | 'abandoned'
    FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);

-- Ephemeral keystrokes: raw event data, DELETED after feature extraction
-- This table is intentionally not backed up and uses WAL mode for performance
CREATE TABLE ephemeral_keystrokes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(id),
    event_type TEXT NOT NULL,               -- 'keydown' | 'keyup' | 'input' | etc.
    key TEXT NOT NULL,                      -- Key value ('a', 'Enter', 'Backspace')
    code TEXT NOT NULL,                     -- Physical key code ('KeyA', 'Enter')
    timestamp_ms REAL NOT NULL,             -- DOMHighResTimeStamp
    shift_key INTEGER NOT NULL DEFAULT 0,   -- Boolean
    ctrl_key INTEGER NOT NULL DEFAULT 0,
    alt_key INTEGER NOT NULL DEFAULT 0,
    meta_key INTEGER NOT NULL DEFAULT 0,
    is_repeat INTEGER NOT NULL DEFAULT 0,
    is_composing INTEGER NOT NULL DEFAULT 0,
    sequence_number INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);
CREATE INDEX idx_ephemeral_session_ts ON ephemeral_keystrokes(session_id, timestamp_ms);

-- Feature vectors: extracted per window, persistent
CREATE TABLE feature_vectors (
    id TEXT PRIMARY KEY,                    -- UUID v4
    session_id TEXT NOT NULL REFERENCES sessions(id),
    window_start_ms REAL NOT NULL,
    window_end_ms REAL NOT NULL,
    keystroke_count INTEGER NOT NULL,
    vector_json TEXT NOT NULL,              -- Full FeatureVector as JSON
    commitment_hash TEXT NOT NULL,          -- SHA-256 hex of this vector's commitment
    created_at TEXT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);
CREATE INDEX idx_fv_session ON feature_vectors(session_id);

-- Commitment chain: incremental hash chain per document
CREATE TABLE commitment_chain (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT NOT NULL REFERENCES documents(id),
    sequence_num INTEGER NOT NULL,
    commitment_hash TEXT NOT NULL,          -- SHA-256 hex
    previous_hash TEXT,                    -- NULL for first entry
    nonce TEXT NOT NULL,                   -- 256-bit nonce, hex-encoded
    timestamp_ms INTEGER NOT NULL,
    UNIQUE(document_id, sequence_num),
    FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);

-- Proof artifacts: generated at publish time
CREATE TABLE proofs (
    id TEXT PRIMARY KEY,                    -- UUID v4
    document_id TEXT NOT NULL REFERENCES documents(id),
    proof_artifact_json TEXT NOT NULL,       -- Full ProofArtifact (Section 8.5)
    verification_level TEXT NOT NULL,        -- 'strong' | 'standard' | 'provisional'
    content_hash TEXT NOT NULL,
    worldid_nullifier TEXT,                 -- WorldID nullifier hash, if verified
    created_at TEXT NOT NULL,
    published_at TEXT,
    published_to TEXT,                      -- 'atproto:at://...' | 'file:/path' | NULL
    FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);

-- Identity: author keypair and WorldID binding
CREATE TABLE identity (
    id TEXT PRIMARY KEY,                    -- UUID v4
    public_key_hex TEXT NOT NULL UNIQUE,    -- Ed25519 public key, hex
    encrypted_private_key_json TEXT NOT NULL,-- EncryptedKeyBundle as JSON
    worldid_nullifier TEXT,                -- WorldID nullifier hash
    worldid_bound_at TEXT,                 -- ISO 8601
    is_active INTEGER NOT NULL DEFAULT 1,  -- Boolean, 0 if rotated away
    rotated_from TEXT,                     -- Previous identity id, if rotated
    created_at TEXT NOT NULL,
    FOREIGN KEY (rotated_from) REFERENCES identity(id)
);

-- Mnemonic backup: encrypted BIP-39 mnemonic for key recovery
CREATE TABLE key_backup (
    id TEXT PRIMARY KEY,
    identity_id TEXT NOT NULL REFERENCES identity(id),
    encrypted_mnemonic TEXT NOT NULL,       -- Argon2id-encrypted mnemonic
    created_at TEXT NOT NULL,
    FOREIGN KEY (identity_id) REFERENCES identity(id) ON DELETE CASCADE
);

-- Author behavioral profile: rolling aggregate across documents (Section 5.5)
CREATE TABLE author_profile (
    id TEXT PRIMARY KEY,
    identity_id TEXT NOT NULL REFERENCES identity(id),
    profile_json TEXT NOT NULL,             -- AuthorBehavioralProfile as JSON
    document_count INTEGER NOT NULL DEFAULT 0,
    effective_documents REAL NOT NULL DEFAULT 0.0,
    last_updated TEXT NOT NULL,
    FOREIGN KEY (identity_id) REFERENCES identity(id) ON DELETE CASCADE
);
```

**Data Lifecycle:**

The ephemeral keystroke data follows a strict lifecycle:

1. **Capture:** Raw events are inserted into `ephemeral_keystrokes` as they arrive from the WebView.
2. **Extraction:** When a window closes (every 5 minutes), events in that window are read, features are extracted, and the resulting `FeatureVector` is stored in `feature_vectors` with its commitment hash.
3. **Destruction:** After successful feature extraction and commitment, the corresponding rows in `ephemeral_keystrokes` are permanently deleted. This is the ephemeral zone boundary (Section 4.2).
4. **Verification:** An integrity check confirms the deletion:

```rust
pub fn purge_extracted_events(db: &Connection, session_id: &str, window_end: f64) -> Result<u64> {
    let deleted = db.execute(
        "DELETE FROM ephemeral_keystrokes WHERE session_id = ?1 AND timestamp_ms < ?2",
        params![session_id, window_end],
    )?;

    // Verify deletion
    let remaining: i64 = db.query_row(
        "SELECT COUNT(*) FROM ephemeral_keystrokes WHERE session_id = ?1 AND timestamp_ms < ?2",
        params![session_id, window_end],
        |row| row.get(0),
    )?;
    assert_eq!(remaining, 0, "Ephemeral data purge verification failed");

    Ok(deleted as u64)
}
```

---

### 14.3 Frontend Architecture

The frontend is a single-page application rendered in the OS WebView, built with TypeScript, React, and TipTap.

#### 14.3.1 Technology Stack

```
Frontend Stack:
├── React 19.x                    # UI framework
├── TipTap 2.x                   # Rich text editor (ProseMirror wrapper)
│   ├── @tiptap/core
│   ├── @tiptap/starter-kit
│   ├── @tiptap/extension-placeholder
│   └── Custom extensions (see below)
├── Zustand 5.x                  # State management
├── @tauri-apps/api 2.x          # Tauri IPC bridge
├── Tailwind CSS 4.x             # Styling
└── Vite 6.x                     # Build tool
```

#### 14.3.2 TipTap Extensions

Three custom TipTap extensions implement the observer-side protocol:

**KeystrokeObserver Extension:**

This extension captures all keyboard, input, and composition events from the ProseMirror editor view and forwards them to the Rust core via Tauri IPC.

```typescript
import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { invoke } from '@tauri-apps/api/core';

const keystrokeObserverKey = new PluginKey('keystrokeObserver');

let sequenceCounter = 0;

export const KeystrokeObserver = Extension.create({
  name: 'keystrokeObserver',

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key: keystrokeObserverKey,
        props: {
          handleDOMEvents: {
            keydown: (view, event) => {
              recordEvent('KeyDown', event);
              return false; // Don't consume the event
            },
            keyup: (view, event) => {
              recordEvent('KeyUp', event);
              return false;
            },
            compositionstart: (view, event) => {
              recordEvent('CompositionStart', event);
              return false;
            },
            compositionupdate: (view, event) => {
              recordEvent('CompositionUpdate', event);
              return false;
            },
            compositionend: (view, event) => {
              recordEvent('CompositionEnd', event);
              return false;
            },
            paste: (view, event) => {
              recordEvent('Paste', event);
              return false;
            },
            cut: (view, event) => {
              recordEvent('Cut', event);
              return false;
            },
          },
        },
      }),
    ];
  },
});

// Batched event recording for performance
let eventBatch: KeystrokeEvent[] = [];
let batchTimer: number | null = null;
const BATCH_INTERVAL_MS = 16; // ~60fps

function recordEvent(type: string, event: Event) {
  const ke = event as KeyboardEvent;
  const keystrokeEvent: KeystrokeEvent = {
    event_type: type,
    key: ke.key ?? '',
    code: ke.code ?? '',
    timestamp: performance.now() + performance.timeOrigin,
    shift_key: ke.shiftKey ?? false,
    ctrl_key: ke.ctrlKey ?? false,
    alt_key: ke.altKey ?? false,
    meta_key: ke.metaKey ?? false,
    repeat: ke.repeat ?? false,
    is_composing: ke.isComposing ?? false,
    sequence_number: sequenceCounter++,
  };

  eventBatch.push(keystrokeEvent);

  if (!batchTimer) {
    batchTimer = window.setTimeout(flushBatch, BATCH_INTERVAL_MS);
  }
}

async function flushBatch() {
  batchTimer = null;
  if (eventBatch.length === 0) return;

  const batch = eventBatch;
  eventBatch = [];

  // Single IPC call for the entire batch
  await invoke('record_keystroke_batch', { events: batch });
}

interface KeystrokeEvent {
  event_type: string;
  key: string;
  code: string;
  timestamp: number;
  shift_key: boolean;
  ctrl_key: boolean;
  alt_key: boolean;
  meta_key: boolean;
  repeat: boolean;
  is_composing: boolean;
  sequence_number: number;
}
```

**SessionManager Extension:**

```typescript
import { Extension } from '@tiptap/core';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';

export const SessionManager = Extension.create({
  name: 'sessionManager',

  addStorage() {
    return {
      sessionId: null as string | null,
      documentId: null as string | null,
      checkpointInterval: null as number | null,
    };
  },

  onCreate() {
    // Start a new session when the editor mounts
    this.startSession();

    // Listen for checkpoint events from Rust core
    listen('session-checkpoint', (event) => {
      this.storage.onCheckpoint?.(event.payload);
    });
  },

  onDestroy() {
    this.endSession();
  },

  addCommands() {
    return {
      startSession: () => async () => {
        await this.startSession();
        return true;
      },
      endSession: () => async () => {
        await this.endSession();
        return true;
      },
    };
  },

  async startSession() {
    const docId = this.storage.documentId;
    const result = await invoke<{ session_id: string }>('start_session', {
      documentId: docId,
    });
    this.storage.sessionId = result.session_id;

    // Set up periodic checkpoints (every 5 minutes)
    this.storage.checkpointInterval = window.setInterval(async () => {
      if (this.storage.sessionId) {
        await invoke('checkpoint_session', {
          sessionId: this.storage.sessionId,
        });
      }
    }, 300_000);
  },

  async endSession() {
    if (this.storage.checkpointInterval) {
      clearInterval(this.storage.checkpointInterval);
    }
    if (this.storage.sessionId) {
      await invoke('end_session', {
        sessionId: this.storage.sessionId,
      });
      this.storage.sessionId = null;
    }
  },
});
```

**ProofStatus Extension:**

```typescript
import { Extension } from '@tiptap/core';
import { listen } from '@tauri-apps/api/event';

export interface ProofState {
  status: 'idle' | 'capturing' | 'extracting' | 'ready' | 'publishing' | 'published';
  commitmentCount: number;
  lastCommitmentHash: string | null;
  keystrokeCount: number;
  sessionDuration: number;     // seconds
  trustScore: number | null;   // 0.0 - 1.0, null if first document
  verificationLevel: 'strong' | 'standard' | 'provisional' | null;
}

export const ProofStatus = Extension.create({
  name: 'proofStatus',

  addStorage() {
    return {
      proofState: {
        status: 'idle',
        commitmentCount: 0,
        lastCommitmentHash: null,
        keystrokeCount: 0,
        sessionDuration: 0,
        trustScore: null,
        verificationLevel: null,
      } as ProofState,
      listeners: [] as Array<() => void>,
    };
  },

  onCreate() {
    // Listen for proof status updates from Rust core
    const unlisten1 = listen<Partial<ProofState>>('proof-status-changed', (event) => {
      Object.assign(this.storage.proofState, event.payload);
    });

    const unlisten2 = listen<{ count: number }>('session-checkpoint', (event) => {
      this.storage.proofState.commitmentCount = event.payload.count;
      this.storage.proofState.status = 'capturing';
    });
  },
});
```

#### 14.3.3 UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Speakwrite                              ─ □ ✕       │
├────────────────────────────────────┬────────────────────────┤
│                                    │   Proof Status         │
│                                    │   ──────────────       │
│                                    │   ● Capturing          │
│                                    │   Keystrokes: 4,231    │
│                                    │   Commitments: 3/3     │
│                                    │   Duration: 14m 22s    │
│         Document Editor            │                        │
│        (TipTap/ProseMirror)        │   Trust Score          │
│                                    │   ██████████░░ 0.84    │
│                                    │   (12 prior documents) │
│                                    │                        │
│                                    │   Commitment Chain     │
│                                    │   ┌─ C₀ a3f2...       │
│                                    │   ├─ C₁ 7b1e...       │
│                                    │   └─ C₂ e9d4... (now) │
│                                    │                        │
│                                    ├────────────────────────┤
│                                    │  [Publish ▾]           │
│                                    │  ├ Post to Bluesky     │
│                                    │  ├ Export Markdown      │
│                                    │  └ Export Proof JSON   │
├────────────────────────────────────┴────────────────────────┤
│  Words: 847  │  Paragraphs: 12  │  Session: 14m            │
└─────────────────────────────────────────────────────────────┘
```

The UI is divided into three zones:

1. **Editor pane (left, ~70% width).** The TipTap rich text editor. Clean, minimal interface focused on writing. Supports Markdown shortcuts, basic formatting (bold, italic, headings, lists, code blocks, links).

2. **Proof sidebar (right, ~30% width).** Real-time proof status display. Shows commitment chain progress, keystroke count, session duration, and trust score. Non-interactive — purely informational during writing.

3. **Status bar (bottom).** Word count, paragraph count, session timer.

The **Publish dialog** is a modal that appears when the author clicks "Publish." It triggers WorldID verification (if not already cached for this session), lets the author choose a destination, generates the proof artifact, and publishes.

---

### 14.4 Tauri IPC Protocol

The IPC protocol defines the communication contract between the WebView frontend and the Rust core. All commands are invoked from JavaScript via `@tauri-apps/api/core`'s `invoke()` function. All events are emitted from Rust to JavaScript via Tauri's event system.

#### 14.4.1 Commands (Frontend → Rust)

| Command | Parameters | Returns | Latency Target | Description |
|---------|-----------|---------|----------------|-------------|
| `record_keystroke_batch` | `events: KeystrokeEvent[]` | `void` | <2ms for batch of 50 | Hot path. Receives batched keystroke events from the observer. |
| `start_session` | `document_id: String` | `{ session_id: String }` | <10ms | Creates a new writing session for a document. |
| `end_session` | `session_id: String` | `{ feature_vector_summary: FeatureVectorSummary }` | <500ms | Ends a session, triggers final feature extraction. |
| `checkpoint_session` | `session_id: String` | `{ commitment: CommitmentEntry }` | <200ms | Triggers windowed extraction and adds a commitment to the chain. |
| `generate_proof` | `document_id: String, content_hash: String, content_paragraphs: String[]` | `{ proof: ProofArtifact }` | <2s | Generates the full proof artifact (Section 8.5). |
| `verify_worldid` | `proof: String, nullifier_hash: String, merkle_root: String, signal: String` | `{ verified: bool, nullifier: String }` | <5s (network) | Verifies a WorldID ZK proof via the on-chain verifier or cloud API. |
| `publish_atproto` | `proof: ProofArtifact, post_text: String, session_token: String` | `{ at_uri: String, proof_uri: String }` | <5s (network) | Publishes post + proof to AT Protocol (Section 13.5). |
| `export_signed_markdown` | `document_id: String` | `{ markdown: String, proof_json: String, signature: String }` | <500ms | Exports document as signed Markdown + detached proof. |
| `export_widget_html` | `document_id: String` | `{ html: String }` | <200ms | Generates embeddable `<human-verified>` widget HTML (Section 9). |
| `get_author_profile` | (none) | `{ public_key: String, nullifier: String?, trust_score: f64, document_count: u32 }` | <10ms | Returns current author identity info. |
| `get_document_list` | (none) | `{ documents: DocumentSummary[] }` | <50ms | Lists all documents with proof status. |
| `get_proof_details` | `document_id: String` | `{ proof: ProofArtifact?, chain: CommitmentEntry[], vectors: FeatureVectorSummary[] }` | <100ms | Returns full proof details for a document. |
| `setup_identity` | `passphrase: String` | `{ public_key: String, mnemonic: String }` | <3s (Argon2id) | First-run identity creation. |
| `bind_worldid` | `verification_response: WorldIdResponse` | `{ nullifier: String, bound_at: String }` | <5s (network) | Binds WorldID to the author's identity. |
| `rotate_key` | `old_passphrase: String, new_passphrase: String` | `{ new_public_key: String, rotation_proof: String }` | <5s | Rotates the author's signing key (Section 7.1.4). |

#### 14.4.2 Events (Rust → Frontend)

| Event | Payload | Description |
|-------|---------|-------------|
| `proof-status-changed` | `{ status: String, commitmentCount: u32, keystrokeCount: u32 }` | Emitted when proof state changes. |
| `session-checkpoint` | `{ commitment_hash: String, sequence: u32, timestamp: i64 }` | Emitted after each successful checkpoint. |
| `feature-extraction-complete` | `{ window_id: String, keystroke_count: u32 }` | Emitted when a window's features are extracted and ephemeral data is purged. |
| `worldid-verification-result` | `{ verified: bool, error: String? }` | Emitted when async WorldID verification completes. |
| `ephemeral-data-purged` | `{ session_id: String, events_deleted: u64 }` | Emitted after ephemeral keystroke data is destroyed. |
| `publish-progress` | `{ stage: String, progress: f64 }` | Progress updates during publishing. |

#### 14.4.3 Performance Requirements

The keystroke recording path is the most performance-critical IPC channel. A fast typist can produce 10-15 keydown events per second, each of which generates both a keydown and keyup event plus potentially an input event. At peak, this is ~45 events per second.

**Batching strategy:**

Events are batched in the frontend with a 16ms flush interval (~60fps). At typical typing speed, each batch contains 1-3 events. At peak typing speed, batches may contain 5-10 events. The Rust handler processes each batch in a single database transaction.

```rust
#[tauri::command]
async fn record_keystroke_batch(
    events: Vec<KeystrokeEvent>,
    state: tauri::State<'_, AppState>,
) -> Result<(), String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;
    let session = state.active_session.lock().map_err(|e| e.to_string())?;

    let session = session.as_ref().ok_or("No active session")?;

    // Single transaction for the entire batch
    let tx = db.transaction().map_err(|e| e.to_string())?;
    for event in &events {
        validate_event(event, session).map_err(|e| e.to_string())?;
        insert_event(&tx, session.id(), event).map_err(|e| e.to_string())?;
    }
    tx.commit().map_err(|e| e.to_string())?;

    // Update in-memory keystroke count
    state.keystroke_count.fetch_add(events.len() as u64, Ordering::Relaxed);

    Ok(())
}
```

**Benchmark targets:**

| Operation | Target | Measurement Method |
|-----------|--------|-------------------|
| Single `record_keystroke_batch` (5 events) | <2ms | `performance.now()` around `invoke()` |
| `checkpoint_session` | <200ms | End-to-end including feature extraction |
| `generate_proof` | <2s | Including Merkle tree and segment map |
| Editor input latency impact | <5ms added | Measured via input event → render delta |

---

### 14.5 Security Architecture

#### 14.5.1 Process Isolation

The security boundary between the WebView and Rust core is enforced by Tauri's IPC mechanism:

- **Private key material** is generated, stored, and used exclusively in the Rust process. The WebView never sees a private key, a decrypted mnemonic, or an unencrypted key bundle.
- **Behavioral feature vectors** are computed in the Rust process. The WebView receives only aggregate summaries for display (commitment count, keystroke count, trust score) — never the full digraph matrix or statistical distributions.
- **Proof artifacts** are constructed entirely in Rust. The WebView receives the completed, signed artifact only for display or transmission.

#### 14.5.2 WebView Content Security Policy

The Tauri application enforces a strict CSP on the WebView:

```json
{
  "security": {
    "csp": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://developer.worldcoin.org https://bridge.worldcoin.org; font-src 'self'"
  }
}
```

Key restrictions:
- No external script loading (`script-src 'self'` only)
- No inline scripts (no `eval()`, no inline event handlers)
- Image sources restricted to self and data URIs
- Network connections restricted to WorldID bridge (used only at publish time) and self (Tauri IPC)

#### 14.5.3 Tauri Capability Allowlist

The application requests the minimum Tauri capabilities:

```json
{
  "permissions": [
    "core:default",
    "core:event:default",
    "core:event:allow-emit",
    "core:event:allow-listen",
    "dialog:default",
    "dialog:allow-save",
    "dialog:allow-open",
    "fs:allow-read-text-file",
    "fs:allow-write-text-file",
    "shell:allow-open"
  ]
}
```

Explicitly **not** granted:
- `shell:allow-execute` — no arbitrary command execution
- `fs:allow-read-file` / `fs:allow-write-file` (binary) — only text file operations for document export
- `http:default` — no arbitrary HTTP requests from the WebView; all network communication goes through Rust commands
- `clipboard-manager:default` — clipboard is handled via ProseMirror's built-in clipboard handling, not Tauri's clipboard API

#### 14.5.4 Network Isolation

The application is **fully offline** during the capture and writing phase. No network requests are made until the author explicitly triggers a publish action.

Network access is required only for:

1. **WorldID verification** — HTTP request to the WorldID cloud verifier or on-chain verification. Occurs once per publish action.
2. **AT Protocol publishing** — XRPC calls to the author's PDS (Personal Data Server). Occurs once per publish action.
3. **Auto-update checks** — Periodic check for application updates via Tauri's updater. Can be disabled by the user.

All network requests are initiated from the Rust core, never from the WebView. The WebView's CSP `connect-src` is restricted to prevent any unauthorized network access from JavaScript.

#### 14.5.5 Audit Log

All security-relevant operations are logged to a local audit log for user inspection:

```sql
CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,          -- ISO 8601
    event_type TEXT NOT NULL,         -- See below
    details_json TEXT,                -- Event-specific details
    success INTEGER NOT NULL          -- Boolean
);
```

Logged events:
- `identity_created` — New keypair generated
- `identity_rotated` — Key rotation performed
- `worldid_bound` — WorldID linked to identity
- `session_started` — Writing session began
- `session_ended` — Writing session ended
- `ephemeral_purged` — Keystroke data destroyed after extraction
- `proof_generated` — Proof artifact created
- `proof_published` — Proof published to external platform
- `key_exported` — Mnemonic backup exported
- `key_imported` — Identity restored from mnemonic

---

### 14.6 Build and Distribution

#### 14.6.1 Supported Platforms

| Platform | Architecture | WebView Engine | Status |
|----------|-------------|----------------|--------|
| macOS | aarch64 (Apple Silicon) | WKWebView | Primary |
| macOS | x86_64 (Intel) | WKWebView | Supported |
| Linux | x86_64 | WebKitGTK 4.1 | Supported |
| Linux | aarch64 | WebKitGTK 4.1 | Supported |
| Windows | x86_64 | WebView2 (Edge) | Supported |

#### 14.6.2 Build System

The application uses a monorepo structure managed by pnpm workspaces:

```
speakwrite/
├── package.json                    # Root workspace
├── pnpm-workspace.yaml
├── pnpm-lock.yaml
├── apps/
│   └── desktop/
│       ├── package.json            # Frontend dependencies
│       ├── vite.config.ts
│       ├── index.html
│       ├── src/
│       │   ├── main.tsx            # React entry point
│       │   ├── App.tsx             # Root component
│       │   ├── components/
│       │   │   ├── Editor.tsx      # TipTap editor wrapper
│       │   │   ├── ProofSidebar.tsx
│       │   │   ├── PublishDialog.tsx
│       │   │   ├── SetupWizard.tsx
│       │   │   └── StatusBar.tsx
│       │   ├── extensions/
│       │   │   ├── keystroke-observer.ts
│       │   │   ├── session-manager.ts
│       │   │   └── proof-status.ts
│       │   ├── stores/
│       │   │   ├── document-store.ts
│       │   │   ├── session-store.ts
│       │   │   └── identity-store.ts
│       │   └── lib/
│       │       ├── tauri-commands.ts  # Typed IPC wrappers
│       │       └── types.ts           # Shared TypeScript types
│       └── src-tauri/
│           ├── Cargo.toml
│           ├── tauri.conf.json
│           ├── capabilities/
│           │   └── default.json
│           ├── icons/
│           └── src/
│               ├── main.rs
│               └── commands/
├── packages/
│   ├── core/                       # speakwrite-core Rust crate
│   │   ├── Cargo.toml
│   │   └── src/                    # (Module layout per Section 14.2.1)
│   ├── verification-widget/        # Embeddable <human-verified> web component
│   │   ├── package.json
│   │   └── src/
│   └── proof-schema/               # Shared JSON schemas and TypeScript types
│       ├── package.json
│       └── src/
└── .github/
    └── workflows/
        ├── ci.yml                  # Lint, test, build on all platforms
        ├── release.yml             # Tagged release builds
        └── security-audit.yml      # cargo audit, npm audit
```

**Build commands:**

```bash
# Development (hot-reload frontend, debug Rust)
cd apps/desktop && pnpm tauri dev

# Production build for current platform
cd apps/desktop && pnpm tauri build

# Run Rust tests
cd packages/core && cargo test

# Run frontend tests
cd apps/desktop && pnpm test

# Full CI (all platforms, via GitHub Actions)
# See .github/workflows/ci.yml
```

#### 14.6.3 Binary Size Targets

| Platform | Format | Target Size |
|----------|--------|-------------|
| macOS | `.dmg` | <25 MB |
| macOS | `.app` (uncompressed) | <40 MB |
| Linux | `.AppImage` | <30 MB |
| Linux | `.deb` | <20 MB |
| Windows | `.msi` | <25 MB |
| Windows | `.exe` (NSIS) | <20 MB |

These targets are achievable because Tauri does not bundle a browser engine. The binary contains only the Rust core (~5-10 MB compiled), the frontend assets (~3-5 MB), and Tauri's framework overhead (~2-3 MB). The OS provides the WebView.

#### 14.6.4 Code Signing and Distribution

| Platform | Signing Method | Distribution |
|----------|---------------|--------------|
| macOS | Apple Developer ID + notarization | `.dmg` via GitHub Releases, Homebrew cask |
| Linux | GPG signature on release assets | `.AppImage` via GitHub Releases, Flatpak (future) |
| Windows | Authenticode (EV code signing certificate) | `.msi` via GitHub Releases, winget (future) |

#### 14.6.5 Auto-Update

The application uses Tauri's built-in updater with Ed25519 signature verification:

```json
{
  "plugins": {
    "updater": {
      "active": true,
      "dialog": true,
      "pubkey": "<Ed25519 public key for update signing>",
      "endpoints": [
        "https://releases.speakwrite.org/{{target}}/{{arch}}/{{current_version}}"
      ]
    }
  }
}
```

Updates are:
- **Signed** with an Ed25519 key controlled by the project maintainers (separate from the author's identity key)
- **User-controllable** — the user can disable auto-update checks entirely
- **Transparent** — update contents are shown before installation
- **Atomic** — failed updates roll back to the previous version

---

### 14.7 User Experience Flows

#### 14.7.1 First Launch

```
1. Welcome screen → explain what Speakwrite does
2. Create passphrase → user enters a strong passphrase
3. Key generation → Ed25519 keypair generated, encrypted with Argon2id
4. Mnemonic backup → display 24-word BIP-39 mnemonic, user confirms backup
5. WorldID binding (optional) → "Connect WorldID for Sybil resistance"
   → Opens WorldID IDKit widget → user verifies via World App or Orb
   → Nullifier hash stored locally
6. Ready → editor opens with a blank document
```

#### 14.7.2 Writing Flow

```
1. Open editor (new document or existing)
2. Session starts automatically → observer begins capturing
3. Write naturally → sidebar shows live proof status:
   - Keystroke count incrementing
   - Commitment chain growing (new entry every 5 minutes)
   - Trust score updating (if prior documents exist)
4. Pause/resume is handled transparently:
   - Closing the app → session ends, partial features extracted
   - Reopening → new session for the same document, chain continues
5. No network access during writing — fully offline
```

#### 14.7.3 Publishing Flow

```
1. Author clicks "Publish" → publish dialog opens
2. Choose destination:
   a. "Post to Bluesky" → requires AT Protocol session
   b. "Export Signed Markdown" → saves .md + .proof.json to disk
   c. "Export Proof JSON" → saves standalone proof artifact
   d. "Generate Widget HTML" → saves embeddable <human-verified> HTML
3. WorldID verification (if bound and not cached):
   → IDKit widget appears → user verifies
   → ZK proof generated and included in proof artifact
4. Proof generation:
   → Final feature extraction for current window
   → Content hash computed over final document
   → Segment map built (content-behavior entanglement)
   → ProofArtifact constructed and signed
5. Publication:
   → For Bluesky: applyWrites batch (post + proof record)
   → For export: files written to chosen location
6. Confirmation → proof artifact hash displayed, link to published post
```

#### 14.7.4 Proof Inspection

Authors and verifiers can inspect any published proof:

- **Commitment chain:** Full list of incremental commitments with timestamps, showing the proof was built progressively during composition.
- **Behavioral summary:** Non-identifying aggregate statistics (words per minute, revision rate, session duration) that demonstrate human-like composition patterns without revealing the author's biometric fingerprint.
- **Verification status:** Whether the proof passes all verification checks (Section 8.6).
- **Trust score:** Progressive trust value based on the author's publication history.
- **WorldID status:** Whether a valid personhood proof is included (without revealing the author's identity).

---

### 14.8 Implementation Checklist

**Phase 1: Core Editor + Capture (MVP)**
- [ ] Initialize Tauri 2.x project with React + Vite frontend
- [ ] Implement TipTap editor with basic formatting (bold, italic, headings, lists, code)
- [ ] Implement KeystrokeObserver extension with batched IPC
- [ ] Implement Rust capture module (event validation, ephemeral buffer)
- [ ] Implement SQLite storage with schema migrations
- [ ] Implement SessionManager extension with session lifecycle
- [ ] Implement Tier 1 and Tier 2 feature extraction
- [ ] Implement ephemeral data purge after extraction
- [ ] Build proof sidebar with live keystroke count and session timer
- [ ] Implement document save/load (ProseMirror JSON to SQLite)

**Phase 2: Full Feature Extraction + Crypto**
- [ ] Implement Tiers 3-6 feature extraction
- [ ] Implement windowed extraction pipeline with 5-min windows
- [ ] Implement incremental commitment chain
- [ ] Implement Ed25519 key generation and Argon2id-encrypted storage
- [ ] Implement BIP-39 mnemonic backup
- [ ] Implement content-behavior segment_map entanglement
- [ ] Implement ProofArtifact construction (Section 8.5)
- [ ] Implement Merkle tree for multi-session documents
- [ ] Build setup wizard (passphrase, key generation, mnemonic)
- [ ] Implement self-verification of generated proofs

**Phase 3: WorldID Integration**
- [ ] Integrate WorldID IDKit v2 in WebView
- [ ] Implement WorldID binding flow (first-time + re-binding)
- [ ] Implement nullifier management and caching
- [ ] Implement WorldID verification bridge (Rust → cloud/on-chain verifier)
- [ ] Add WorldID proof to ProofArtifact

**Phase 4: Publishing + Export**
- [ ] Implement signed Markdown export
- [ ] Implement standalone proof JSON export
- [ ] Implement embeddable widget HTML generation (Section 9)
- [ ] Implement AT Protocol session management (OAuth via atrium)
- [ ] Implement applyWrites batch publishing (Section 13.5)
- [ ] Build publish dialog with destination selection

**Phase 5: Polish + Distribution**
- [ ] Implement cross-document consistency model (Section 5.5)
- [ ] Implement progressive trust score display
- [ ] Implement key rotation flow
- [ ] Implement audit log and viewer
- [ ] Set up Tauri auto-updater with Ed25519 signing
- [ ] Set up CI/CD for macOS, Linux, Windows builds
- [ ] macOS notarization and code signing
- [ ] Windows Authenticode signing
- [ ] Write user-facing documentation
- [ ] Security audit of Rust crypto module
- [ ] Performance benchmarking (IPC latency, memory usage, binary size)

---

*End of Section 14: Desktop Application Architecture.*

---

## 15. Rebuttals and Limitations

This section addresses known criticisms of the Speakwrite approach directly and honestly. A protocol that cannot withstand scrutiny from adversaries, skeptics, and ethicists is not worth building. Each rebuttal is presented in the strongest form we can construct, followed by our response and, where applicable, acknowledgment of irreducible limitations.

### 15.1 Fundamental Limitations

#### 15.1.1 The Transcription Problem

**Criticism:** "A human can open ChatGPT in one window and Speakwrite in another, read the AI-generated text, and type it. The resulting proof is indistinguishable from original composition."

**Assessment: Partially valid. This is the irreducible lower bound of process-based verification.**

Speakwrite attests that a physical human typing process occurred. It cannot determine whether the ideas being typed originated in the author's mind, were copied from a source, or were dictated by a machine. A skilled transcriber who reads a sentence, internalizes it, and then types it from memory will produce keystroke dynamics that closely resemble original composition.

**Mitigations (partial, not complete):**

1. **Transcription behavioral signatures.** Section 5.1.5 (Linguistic-Temporal Correlation) identifies statistical anomalies in transcribed text: abnormally uniform word timing across complexity levels, absence of the characteristic "word-boundary slowdown" pattern that occurs during original composition when the writer is selecting words, and atypical pause distributions (reading pauses at beginnings of sentences rather than mid-sentence cognitive pauses). These signals are probabilistic and can be defeated by a skilled transcriber.

2. **Cognitive load mismatch.** Original composition produces measurable cognitive load variation — pauses correlate with syntactic complexity, lexical rarity, and argument structure. Transcription flattens this correlation because the cognitive work is reading, not composing. The Tier 5 features (Section 5.1.5) capture this, but the signal weakens as the transcriber becomes more skilled at absorbing and reproducing text naturally.

3. **Cost escalation.** Even if transcription can fool the system, it imposes a significant cost: the transcriber must type the entire document at human speed. This eliminates the primary advantage of AI text generation — speed and scale. A bad actor who must spend 30 minutes typing a 1,000-word article cannot flood a platform with thousands of verified posts.

**Honest conclusion:** A determined, skilled transcriber can defeat Speakwrite. The protocol does not and cannot solve this. It raises the cost of deception from zero (copy-paste AI output) to substantial (full manual transcription at human speed), which changes the economics of AI-generated content at scale but does not prevent individual acts of deception.

#### 15.1.2 Process vs. Cognition

**Criticism:** "You're proving motor activity, not thought. The badge says 'human written' but the ideas might still come from an AI. This creates a false sense of authenticity."

**Assessment: Valid. Speakwrite proves process, not cognition. This is a feature, not a bug — but requires careful communication.**

No system can prove that ideas originated in a human mind. Even a handwritten document could contain ideas copied from a book. The distinction between "human-typed" and "human-conceived" is real and important, and the Speakwrite badge must not conflate them.

**Response:**

1. The protocol specification explicitly states this limitation as a non-goal (Section 2.3). The abstract uses the phrase "forensic evidence" rather than "proof" to signal the probabilistic nature of the attestation.

2. The verification widget (Section 9) should display "Human Typed" or "Human Keystroke Verified" rather than "Human Written" to avoid implying cognitive originality. The distinction matters.

3. The value proposition is not "this person had no AI assistance" — it is "this document was produced through a physical typing process by a verified unique person, and the cost of faking this is high." This is still useful information for readers evaluating content provenance.

**Honest conclusion:** Speakwrite cannot and does not solve the problem of AI-assisted ideation. A human who uses ChatGPT to brainstorm ideas and then writes the document in their own words, typing original sentences informed by AI suggestions, will produce a valid proof — and arguably, that *should* be valid. The line between "AI-assisted thinking" and "AI-generated text" is blurry, and Speakwrite does not attempt to draw it.

#### 15.1.3 The Arms Race

**Criticism:** "As AI models improve at simulating human behavior — including motor patterns — the gap between real and synthetic keystroke dynamics will close. You're buying time, not solving the problem."

**Assessment: Partially valid, but the asymmetry favors the defender more than critics assume.**

**Response:**

1. **Keystroke dynamics are high-dimensional and individually distinctive.** A digraph timing matrix for a single author contains ~2,000-5,000 populated cells, each with a full statistical distribution. Replicating this consistently across documents, over time, with cross-document consistency checks, requires maintaining a generative model of an individual human's motor behavior at sub-millisecond precision. This is a significantly harder problem than generating plausible text.

2. **The physical bottleneck is real.** Even a perfect behavioral simulator must somehow inject synthetic keystrokes into the system. This requires either:
   - Software-level event injection (detectable via the event validation in Section 14.2.4)
   - Hardware-level injection (Section 15.2.1)
   - A modified Speakwrite binary (Section 15.2.3)
   
   Each of these has its own cost and detection surface.

3. **Progressive trust is cumulative.** An adversary who builds a perfect simulator for one document must maintain that simulation across dozens of documents over months or years, with consistent behavioral drift patterns that match natural human motor learning. The trust model (Section 5.6) is designed so that defeating it gets harder over time, not easier.

4. **The baseline shifts.** As simulation capability improves, the feature extraction engine can be updated with new tiers of analysis that target the latest generation of simulators. The protocol is versioned (Section 5.2.3) specifically to enable this evolution.

**Honest conclusion:** Speakwrite is engaged in an arms race. The key question is whether the cost of simulation remains higher than the cost of simply hiring a human to write. As long as that economic inequality holds, the protocol provides value. If AI motor simulation becomes cheap and accurate, the protocol's value degrades. We believe the physical and computational constraints on keystroke simulation provide a longer runway than text generation detection, but we do not claim permanence.

### 15.2 Practical Attack Surfaces

#### 15.2.1 Hardware Keystroke Injection

**Criticism:** "A USB device like a Rubber Ducky or O.MG cable can inject keystrokes with arbitrary timing. To the OS, these are indistinguishable from real keystrokes. You can buy one for $50."

**Assessment: Valid. Hardware injection is the most difficult attack to defend against.**

A hardware keystroke injector that sits between the keyboard and the computer (or replaces the keyboard entirely) can produce events that are, at the OS API level, identical to real keypresses. If the injector replays captured human timing patterns while typing AI-generated text, the resulting behavioral profile will be indistinguishable from genuine typing.

**Mitigations (limited):**

1. **Timing precision artifacts.** USB HID devices have a polling rate (typically 125Hz-1000Hz, i.e., 1-8ms resolution). Real keyboards have similar polling rates, but the interaction between the USB polling interval and the OS event timestamp may produce detectable quantization artifacts. This is fragile and platform-dependent.

2. **Typing rhythm naturalness.** A replay-based injector using captured timing from *a different text* will produce digraph timing distributions that match the source typist but may not match the cognitive demands of the target text. The Tier 5 linguistic-temporal correlation features may detect this mismatch.

3. **Cost escalation.** Hardware injection at the quality needed to defeat Speakwrite requires: (a) a hardware device, (b) a corpus of captured typing data from a real human, (c) a timing replay algorithm that adapts captured patterns to new text, and (d) integration testing to verify the proof passes. This is significantly more expensive than copy-pasting AI output, which is the threat model's design target.

**Honest conclusion:** A well-funded adversary with hardware access to the target machine can defeat Speakwrite. The protocol does not defend against physical compromise of the input device. This is acknowledged in the threat model (Section 3.2, Adversary Class 3: Sophisticated Simulator).

#### 15.2.2 Open Source Feature Set Exploitation

**Criticism:** "The spec is public. I know exactly what features you extract. Given enough real typing data, I can build a simulator that produces realistic FeatureVectors."

**Assessment: Valid, and intentional. Security through obscurity is not a design goal.**

**Response:**

1. **Knowing the features does not make simulation cheap.** The digraph timing matrix alone has ~5,000 cells with full distributions. Cross-document consistency (Section 5.5) requires that these distributions remain stable over time with natural drift. The Mahalanobis distance check compares each new document against the accumulated profile, and statistical inconsistencies compound: a simulator that is 95% accurate per feature will fail at the 150-feature level.

2. **The protocol invites scrutiny.** An open feature set means that researchers, not just adversaries, can evaluate and improve the system. A secret feature set that is eventually reverse-engineered provides a false sense of security followed by total compromise. An open feature set that is designed to be hard to simulate provides honest, durable security.

3. **Feature set evolution is expected.** The protocol versions its feature vectors (Section 5.2.3). New features can be added as simulation techniques improve. The openness of the current feature set is a tradeoff that enables community contribution to the defense.

#### 15.2.3 Modified Observer Binary

**Criticism:** "Someone can fork Speakwrite, modify the observer to inject fake behavioral data, and produce proofs that look legitimate."

**Assessment: Valid. This is the open-source observer integrity problem.**

A modified binary can produce any behavioral data it wants. The commitment chain, signatures, and WorldID verification will all pass because they are computed correctly — just over fabricated inputs.

**Mitigations:**

1. **Code signing and reproducible builds.** Official releases are signed with a known key and built deterministically from the public source code. Verifiers can check whether a proof was generated by an official build (though this requires trusting the build infrastructure and is not included in the current verification procedure).

2. **Behavioral consistency across the ecosystem.** A modified binary producing fabricated behavioral data must produce data that is statistically consistent with real human typing across all feature dimensions. A naive modification (e.g., randomizing digraph timings) will be detected by baseline model checks. A sophisticated modification requires implementing a full human typing simulator — which returns us to the simulation problem (Section 15.1.3).

3. **Remote attestation (future work).** Section 12 identifies the possibility of TEE-based (Trusted Execution Environment) attestation of the observer process. This would provide hardware-backed assurance that the observer code was not modified. This is not included in the current protocol because it introduces hardware trust requirements that conflict with the open-source philosophy.

**Honest conclusion:** In the current protocol, observer integrity depends on the user running unmodified software. There is no cryptographic mechanism to prove that the observer was not modified. This is a known limitation shared by all local-first attestation systems.

### 15.3 Ethical and Social Concerns

#### 15.3.1 Accessibility Exclusion

**Criticism:** "People who use speech-to-text, eye tracking, switch controls, or any non-keyboard input method can't produce valid Speakwrite proofs. This excludes disabled writers from the 'verified human' ecosystem."

**Assessment: Valid and serious. This must be addressed.**

Speakwrite's current design assumes keyboard input as the primary composition method. Users who rely on assistive input technologies — including but not limited to:

- Voice dictation (macOS Dictation, Dragon NaturallySpeaking, Whisper-based tools)
- Eye-tracking input (Tobii Dynavox, EyeTech)
- Switch scanning input
- Sip-and-puff devices
- Head tracking
- Brain-computer interfaces

— cannot produce the keystroke behavioral evidence that Speakwrite requires.

**Response and commitments:**

1. **Alternative input modalities are a priority extension.** Section 12 should be expanded to define behavioral capture profiles for non-keyboard input methods. Voice dictation has its own behavioral signatures (speech cadence, pause patterns, correction behaviors, filler words) that could serve as an alternative evidence source.

2. **The verification badge must not imply that unverified content is non-human.** The absence of a Speakwrite badge means "not verified," not "AI-generated." This distinction must be enforced in all client implementations, documentation, and marketing.

3. **Platforms that adopt Speakwrite must not require it.** If Speakwrite verification becomes a prerequisite for publishing, visibility, or credibility on a platform, it becomes a tool of exclusion. The protocol specification should include a normative statement that Speakwrite verification MUST remain optional and that platforms MUST NOT penalize unverified content.

**Normative requirement:** Implementations MUST include the following in their UI:

> "Speakwrite verification is available for keyboard-composed content. The absence of verification does not indicate AI-generated content. Many forms of legitimate human writing — including dictated, assistive-technology-composed, and handwritten content — are not currently verifiable by this protocol."

#### 15.3.2 Two-Tier Content Ecosystem

**Criticism:** "Content with a Speakwrite badge gets trusted; content without it gets questioned. This penalizes everyone who doesn't use the tool — including people who value privacy, people in regions where WorldID isn't available, and people who write on platforms that don't support it."

**Assessment: Valid social concern. The protocol cannot prevent its misuse as a gatekeeping mechanism, but can take design steps to resist it.**

**Response:**

1. **Verification is additive, not subtractive.** Speakwrite adds evidence to content that has it. It should never be interpreted as evidence against content that lacks it. The verification widget explicitly does not display a "not verified" state for content that was never submitted for verification.

2. **WorldID availability.** WorldID verification is optional in the protocol (Section 8.3.4). Proofs without WorldID are classified as VERIFIED_NO_PERSONHOOD — a valid verification outcome. The personhood layer adds Sybil resistance but is not required for the behavioral attestation to have value.

3. **Geographic and economic access.** The desktop application is free and open source. WorldID's Orb verification is not universally available, but device-level verification (World App) provides a lower-friction alternative. The protocol should define additional personhood verification methods (Section 12) to reduce single-provider dependency.

4. **Cultural sensitivity.** In some cultural or political contexts, proving identity — even pseudonymously — carries risks. The protocol respects this by making all identity mechanisms optional and ensuring that the core behavioral attestation works without any identity layer.

#### 15.3.3 Solving the Wrong Problem

**Criticism:** "The real issue isn't whether text was typed by a human — it's whether the ideas are valuable, true, and well-reasoned. A human can write garbage and an AI can write insightful analysis. By emphasizing process over content, you devalue good AI-assisted writing while protecting bad human writing."

**Assessment: This is a philosophical disagreement about what matters, not a technical flaw.**

**Response:**

1. **Speakwrite does not claim content quality.** The protocol explicitly states (Section 2.3) that it says nothing about whether content is true, accurate, well-reasoned, or original. It is a provenance tool, not a quality tool.

2. **Provenance is independently valuable.** Knowing that a piece of journalism was composed through a human typing process provides different information than knowing it is well-written. Both are valuable. A reader evaluating a war correspondent's dispatch may care about both the quality of the writing and the evidence that it was composed by a human in the field, not generated from a prompt by someone who was never there.

3. **AI-assisted writing is not the enemy.** The protocol's future extension for AI-assisted tiers (Section 12.3) explicitly envisions a verification level that says "this was written by a human with AI assistance." The goal is transparency about process, not prohibition of tools.

4. **The alternative is worse.** Without process verification, all text is unattributed. Readers have no information about provenance. Speakwrite provides optional, additional information. The criticism amounts to "some information about provenance is worse than no information," which we do not find persuasive.

### 15.4 Technical Dependency Risks

#### 15.4.1 WorldID Single Point of Failure

**Criticism:** "The entire Sybil resistance layer depends on one company (Tools for Humanity / Worldcoin). If WorldID shuts down, changes its API, gets compromised, or is banned in certain jurisdictions, every proof that relies on it becomes unverifiable."

**Assessment: Valid. This is the most significant infrastructure dependency in the protocol.**

**Response and mitigations:**

1. **WorldID is optional.** Proofs without WorldID verification are still valid behavioral attestations. They lack Sybil resistance but retain all other properties. The protocol degrades gracefully.

2. **The personhood verification interface is abstract.** Section 7.2 defines the WorldID binding in terms of a nullifier hash and a ZK proof. Any system that provides (a) proof of unique personhood, (b) a stable pseudonymous identifier (nullifier), and (c) zero-knowledge verification could substitute for WorldID. The protocol should define an abstract PersonhoodProvider interface with WorldID as the reference implementation.

3. **Planned alternative providers:**
   - **Proof of Passport** (ZK proof over NFC passport data) — decentralized, no single vendor
   - **Gitcoin Passport / Civic** — credential aggregation approaches
   - **BrightID** — social graph-based uniqueness
   - **Government digital identity** (eIDAS 2.0, mDL) — where available and privacy-acceptable

4. **Nullifier portability.** If a replacement personhood system is adopted, existing proofs with WorldID nullifiers remain valid for historical verification. New proofs use the new system. The identity certificate (Section 7.3) should be extended to support multiple concurrent personhood bindings.

#### 15.4.2 Biometric Data as Liability

**Criticism:** "The digraph timing matrix is a biometric fingerprint. Publishing proofs with behavioral data enables cross-correlation attacks: an adversary could match an anonymous Speakwrite author to a known person by comparing typing patterns from other sources."

**Assessment: Valid. This is the core privacy-security tradeoff in the protocol.**

The behavioral evidence that makes Speakwrite proofs convincing is the same data that could potentially identify the author. These goals are in tension.

**Response:**

1. **Current mitigation: aggregate-only publication.** The proof artifact (Section 8.5) publishes aggregate statistics (mean flight time, burst rate, revision ratio) rather than the full digraph matrix. These aggregates are less identifying than the full matrix but also provide weaker evidence.

2. **Planned mitigation: ZK behavioral proofs (Section 12.1).** The protocol's roadmap includes zero-knowledge proofs over behavioral features — proving that the features fall within human-normal ranges without revealing the actual values. This eliminates the cross-correlation attack entirely but requires significant cryptographic engineering (ZK circuits over floating-point statistical computations).

3. **Commitment-based selective disclosure (recommended).** The proof artifact commits to the full behavioral feature vector via a hash, but only publishes a subset of features. A verifier who wants stronger evidence can request selective disclosure of specific features, which the author can grant or deny. This puts the author in control of the privacy-evidence tradeoff.

4. **Normative guidance.** Implementations SHOULD warn authors before publishing proof artifacts that contain behavioral data. The warning should explain: "This proof contains statistical summaries of your typing patterns. While individual statistics are not uniquely identifying, the combination of many features may be correlatable with other typing samples. Publishing this proof is voluntary."

### 15.5 Summary of Irreducible Limitations

The following limitations are inherent to the Speakwrite approach and cannot be resolved through protocol improvements:

| Limitation | Why It's Irreducible | Impact |
|-----------|---------------------|--------|
| Skilled transcription defeats verification | No process-based system can distinguish original thought from perfectly internalized transcription | Individual deception possible; mass deception remains expensive |
| Hardware injection is undetectable | OS-level keyboard events are indistinguishable regardless of source | Targeted attacks by funded adversaries succeed |
| Open source enables simulation research | Hiding the feature set provides only temporary security | Continuous feature evolution required |
| Behavioral data has privacy implications | Strong evidence requires revealing behavioral patterns | Fundamental tradeoff, mitigable but not eliminable |
| Cannot prove absence of AI ideation | Thought is unobservable by any physical measurement | Protocol proves process, never cognition |
| Keyboard-centric design excludes some users | Alternative input methods have fundamentally different behavioral signatures | Accessibility extensions needed |

**Design philosophy:** Speakwrite is designed to make deception expensive, not impossible. It shifts the economics of AI-generated content from "free and undetectable" to "costly and risky." The protocol's value is proportional to the cost differential between genuine composition and the cheapest successful attack. As long as that differential remains significant, the protocol provides value. When it does not, the protocol should be retired or fundamentally redesigned.

---

*End of Section 15: Rebuttals and Limitations.*

---

## 16. Device Attestation

### 16.1 Motivation

Section 3 identifies Observer Trust (TA-1) as the protocol's most critical trust assumption. The base protocol cannot prove that the Observer software has not been modified to fabricate behavioral data. Section 15.2.3 acknowledges this openly: a modified binary can produce valid commitment chains over entirely fabricated keystroke data.

Device attestation addresses this by leveraging hardware-backed trust anchors — cryptographic keys embedded in tamper-resistant silicon — to prove that:

1. The Observer is running on a genuine device (not an emulator).
2. The Observer binary has not been modified (code integrity).
3. The keystroke data was signed by hardware that the device manufacturer vouches for.

This does not close the gap entirely (see Section 16.6), but it raises the cost of Observer compromise from "fork the repo and change a function" to "jailbreak a device or build custom hardware."

### 16.2 Trust Hierarchy

Device attestation introduces a four-layer trust hierarchy. Each layer independently strengthens the proof; all layers together provide the strongest available assurance.

```
Layer 4: Behavioral Analysis          (Is this human typing?)
   ↑
Layer 3: Device Attestation           (Is this a real device running genuine code?)
   ↑
Layer 2: Session Biometric Binding    (Was a real person present?)
   ↑
Layer 1: Cryptographic Commitment     (Is the data tamper-evident?)
```

**Layer 1 (base protocol):** The commitment chain, content binding, and signatures ensure data integrity. This is what the protocol provides today.

**Layer 2 (biometric gate):** At session start, the device's biometric system (Face ID, Touch ID, Windows Hello) authenticates the user. The session signing key is locked behind biometric authorization — it literally cannot produce signatures without the user's biometric confirmation.

**Layer 3 (device attestation):** A hardware-backed attestation proves the signing key was generated on a genuine device running unmodified Speakwrite code. The device manufacturer (Apple, Google) acts as the root of trust.

**Layer 4 (behavioral analysis):** The existing Behavioral Feature Vector provides statistical evidence that the keystroke timing patterns are consistent with human motor behavior.

### 16.3 Platform-Specific Mechanisms

#### 16.3.1 Apple Devices (iOS / macOS)

Apple provides two complementary mechanisms, both backed by the Secure Enclave:

**App Attest (`DCAppAttestService`)**

App Attest generates a P-256 key pair inside the Secure Enclave. Apple's attestation servers issue a certificate chain proving:

- The key was generated on a genuine Apple device with a Secure Enclave (A7 chip or later).
- The key is bound to a specific app identified by Bundle ID.
- The device has not been flagged by Apple for fraud.

After one-time attestation, the key can sign arbitrary data via `generateAssertion()`, producing cryptographic assertions over SHA-256 hashes of payloads. Each assertion includes a monotonic counter that prevents replay.

**Secure Enclave Signing (`SecureEnclave.P256.Signing`)**

CryptoKit provides direct access to Secure Enclave P-256 signing keys with biometric access control:

```swift
let accessControl = SecAccessControlCreateWithFlags(
    kCFAllocatorDefault,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet],
    nil
)!

let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
    accessControl: accessControl
)

// This key can ONLY sign when Face ID / Touch ID confirms the enrolled user
let signature = try privateKey.signature(for: keystrokeBatchData)
```

The `dataRepresentation` of a Secure Enclave key is an encrypted blob that only the originating device's Secure Enclave can decrypt. The private key material never exists in main memory.

**Availability:**

| Mechanism | iOS | macOS | Web/PWA |
|-----------|-----|-------|---------|
| App Attest | 14+ | 14+ (Apple Silicon) | No |
| Secure Enclave (CryptoKit) | 13+ | 10.15+ (T2/Apple Silicon) | No |
| Biometric gate (LAContext) | 8+ | 10.12.2+ | No (WebAuthn partial) |

**Limitation:** App Attest returns `isSupported = false` in app extensions (including keyboard extensions). The attestation key must be generated in the containing app and shared via a keychain access group.

#### 16.3.2 Android Devices

**Play Integrity API**

The successor to SafetyNet provides device verdicts:

- `MEETS_DEVICE_INTEGRITY`: Genuine Android device with Google Play Services, verified bootloader.
- `MEETS_BASIC_INTEGRITY`: Device passes basic checks (may be rooted but not emulated).
- `MEETS_STRONG_INTEGRITY`: Hardware-backed key attestation available.

**Android Keystore with StrongBox**

Android 9+ devices with dedicated secure hardware (StrongBox) support hardware-bound signing keys:

```kotlin
val keyGenerator = KeyPairGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore"
)
keyGenerator.initialize(
    KeyGenParameterSpec.Builder("speakwrite_session_key", PURPOSE_SIGN)
        .setDigests(KeyProperties.DIGEST_SHA256)
        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
        .setIsStrongBoxBacked(true)
        .setUserAuthenticationRequired(true)
        .setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)
        .build()
)
val keyPair = keyGenerator.generateKeyPair()
```

**Availability:**

| Mechanism | Android | Web/PWA |
|-----------|---------|---------|
| Play Integrity | 5.0+ (with Play Services) | No |
| StrongBox Keystore | 9+ (hardware dependent) | No |
| Biometric (BiometricPrompt) | 9+ | No (WebAuthn partial) |

#### 16.3.3 Web Browsers

No browser API currently provides hardware-backed device attestation suitable for content signing. The strongest available mechanism is WebAuthn with a hardware security key:

| Signal | Strength | Notes |
|--------|----------|-------|
| WebAuthn (hardware key, e.g. YubiKey) | Strong | Returns `fmt: "packed"` with device attestation certificate |
| WebAuthn (platform authenticator, synced passkey) | Weak | Returns `fmt: "none"` — no device binding |
| WebCrypto (non-extractable key) | Minimal | Software-bound, not hardware-bound |

**Recommendation:** Web clients should support WebAuthn for user binding but MUST NOT claim device attestation unless a hardware security key with a verifiable attestation certificate is used. The proof bundle should indicate the attestation level honestly.

### 16.4 Attestation Protocol

#### 16.4.1 Session Lifecycle with Attestation

```
1. APP LAUNCH (one-time setup)
   ├── Generate Secure Enclave key pair (with biometric access control)
   ├── Attest the key with platform service (App Attest / Play Integrity)
   └── Store attestation certificate and key ID

2. SESSION START
   ├── Require biometric authentication (Face ID / Touch ID / fingerprint)
   ├── Unlock Secure Enclave signing key
   ├── Generate session nonce
   └── Sign session-start record: SE_Sign(session_id ∥ timestamp ∥ nonce)

3. DURING COMPOSITION (every commitment checkpoint)
   ├── Compute commitment_hash per base protocol
   ├── Compute behavioral feature vector for this batch
   ├── Sign the checkpoint: SE_Sign(commitment_hash ∥ bfv_hash ∥ sequence_num)
   └── Store signature in commitment entry

4. SESSION END / PUBLISH
   ├── Compute content binding per base protocol
   ├── Sign final binding: SE_Sign(content_hash ∥ binding_hash ∥ chain_root)
   ├── Assemble proof bundle with attestation envelope
   └── Include: attestation certificate, all checkpoint signatures, device metadata
```

#### 16.4.2 Attestation Envelope

The proof bundle is extended with an optional `device_attestation` field:

```json
{
  "protocol_version": "0.2",
  "content_hash": "sha256:...",
  "binding_hash": "sha256:...",
  "commitments": [ ... ],
  "behavioral_summary": { ... },

  "device_attestation": {
    "platform": "apple",
    "attestation_type": "app_attest",
    "attestation_level": "hardware",

    "device_public_key": "base64(P-256 public key)",
    "attestation_certificate": "base64(App Attest certificate chain)",
    "app_id": "com.speakwrite.ios",

    "session_binding": {
      "session_id": "uuid",
      "biometric_gate": true,
      "session_start_signature": "base64(SE signature over session start)",
      "session_start_timestamp": "2026-02-14T12:00:00Z"
    },

    "checkpoint_signatures": [
      {
        "sequence_num": 0,
        "commitment_hash": "sha256:...",
        "signature": "base64(SE signature)"
      },
      {
        "sequence_num": 1,
        "commitment_hash": "sha256:...",
        "signature": "base64(SE signature)"
      }
    ],

    "final_signature": "base64(SE signature over content binding)"
  }
}
```

#### 16.4.3 Attestation Levels

| Level | Label | Requirements | Trust Signal |
|-------|-------|-------------|-------------|
| 0 | `none` | Base protocol only | Commitment chain is tamper-evident |
| 1 | `software` | WebCrypto non-extractable key | Signed by browser-bound key (software) |
| 2 | `hardware_unverified` | WebAuthn passkey (synced) | User authenticated biometrically; device not attested |
| 3 | `hardware_verified` | WebAuthn with hardware key attestation | Device certificate chain verified |
| 4 | `platform_attested` | App Attest / Play Integrity + Secure Enclave | Platform manufacturer vouches for device + app integrity |

The verification widget (Section 9) should display the attestation level alongside the behavioral confidence score.

### 16.5 Verification of Device Attestations

#### 16.5.1 Apple App Attest Verification

Verification of an App Attest attestation requires:

1. **Certificate chain validation.** The attestation certificate chain roots to Apple's App Attest Root CA (`Apple App Attestation Root CA`). The verifier checks that the certificate is not expired or revoked.

2. **App ID binding.** The attestation contains the SHA-256 hash of the app's App ID (`team_id.bundle_id`). The verifier confirms this matches the expected Speakwrite app identifier.

3. **Key binding.** The attestation binds the public key to the device's Secure Enclave. The verifier extracts the public key and uses it to verify all subsequent assertion signatures.

4. **Assertion verification.** Each checkpoint signature and the final binding signature are ECDSA P-256 signatures. The verifier checks each signature against the attested public key and confirms the signed data matches the commitment chain.

5. **Counter monotonicity.** Each assertion includes a monotonic counter. The verifier checks that counters increase sequentially, preventing replay of individual assertions.

#### 16.5.2 Degraded Verification

If device attestation is present but unverifiable (e.g., the verifier cannot reach Apple's OCSP responder, or the attestation format is from an unrecognized platform), the verifier SHOULD:

1. Verify the base protocol (commitment chain, content binding) as normal.
2. Verify checkpoint signatures against the provided public key (signature math is platform-independent).
3. Note in the verification result that device attestation is present but the certificate chain could not be validated.
4. Assign an intermediate confidence level between "no attestation" and "fully attested."

### 16.6 Limitations of Device Attestation

Device attestation strengthens the proof significantly but does not provide absolute guarantees. The following limitations are inherent:

**L-DA-1: Attestation proves the envelope, not the content.** App Attest proves that data was signed by a genuine Speakwrite app on a genuine Apple device. It does NOT prove that the data being signed reflects real keystroke observations. A subtle code-level exploit within the genuine app (e.g., a malicious library dependency) could fabricate keystroke data before signing.

**L-DA-2: Jailbroken / rooted devices.** A jailbroken iOS device or rooted Android device may be able to intercept Secure Enclave operations or inject data before signing. App Attest includes a fraud risk score, and Play Integrity checks bootloader status, but determined attackers with physical device access may circumvent these checks.

**L-DA-3: Platform trust dependency.** Device attestation transfers trust from "trust the user's software" to "trust the device manufacturer." This is pragmatically useful (Apple and Google have strong incentives to maintain their attestation infrastructure) but is not a decentralized trust model. If Apple's attestation servers are compromised or Apple changes its attestation policies, the trust model changes.

**L-DA-4: Native app requirement.** The strongest attestation (Level 4) requires a native app. This is unavailable to the PWA and desktop Electron/Tauri implementations. The protocol MUST remain functional without device attestation; it is an additive trust signal, not a requirement.

**L-DA-5: Keyboard input gap.** No platform provides a mechanism for the OS keyboard to cryptographically sign its own output. Device attestation proves the app is genuine; behavioral analysis provides evidence the input was human; but there is no cryptographic link between the physical keyboard press and the signed data. This gap can only be closed by future OS-level changes that neither Apple nor Google currently offer.

**Design philosophy:** Device attestation moves the trust boundary from "trust the user's software" to "trust the user's hardware and OS vendor." This is a meaningful improvement for the vast majority of threat scenarios. A user running genuine Speakwrite on a genuine iPhone with Face ID is providing substantially stronger evidence than a user running the web app in a browser. The protocol should reward this with higher attestation levels while remaining honest about what those levels mean.

---

*End of Section 16: Device Attestation.*
