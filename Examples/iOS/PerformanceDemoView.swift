/// PerformanceDemoView.swift
/// Performance benchmarking and visualization for HL7kit parsing.
///
/// Measures message parsing throughput, memory characteristics, and
/// compares different parsing strategies with animated progress
/// indicators and live metrics.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit

// MARK: - Performance Demo View

/// Interactive benchmarking dashboard for HL7 v2.x message parsing.
@MainActor
struct PerformanceDemoView: View {
    @Environment(AppState.self) private var appState

    @State private var messageCount: Double = 1000
    @State private var benchmarkResult: BenchmarkResult?
    @State private var isRunning = false
    @State private var progress: Double = 0
    @State private var strategyResults: [StrategyResult] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    configurationSection
                    if isRunning { progressSection }
                    if let result = benchmarkResult { metricsSection(result) }
                    strategyComparisonSection
                }
                .padding()
            }
            .navigationTitle("Performance")
        }
    }

    // MARK: - Configuration

    @ViewBuilder
    private var configurationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Benchmark Setup", systemImage: "slider.horizontal.3")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Messages to parse")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(messageCount))")
                            .font(.subheadline.monospaced().bold())
                    }
                    Slider(value: $messageCount, in: 100...10000, step: 100)
                        .tint(.blue)
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await runBenchmark() }
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Run Benchmark")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)

                    Button {
                        Task { await runStrategyComparison() }
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Compare")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning)
                }
            }
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                ProgressView(value: progress) {
                    Text("Parsing messages…")
                        .font(.subheadline)
                } currentValueLabel: {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospaced())
                }
                .tint(.blue)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Metrics Dashboard

    @ViewBuilder
    private func metricsSection(_ result: BenchmarkResult) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeaderView(title: "Results", systemImage: "gauge.with.dots.needle.67percent")

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    MetricCard(
                        title: "Throughput",
                        value: String(format: "%.0f", result.messagesPerSecond),
                        unit: "msg/sec",
                        icon: "speedometer",
                        color: .blue
                    )
                    MetricCard(
                        title: "Total Time",
                        value: String(format: "%.2f", result.totalSeconds),
                        unit: "seconds",
                        icon: "clock",
                        color: .purple
                    )
                    MetricCard(
                        title: "Avg Parse",
                        value: String(format: "%.3f", result.avgParseMilliseconds),
                        unit: "ms/msg",
                        icon: "timer",
                        color: .orange
                    )
                    MetricCard(
                        title: "Messages",
                        value: "\(result.messageCount)",
                        unit: "parsed",
                        icon: "doc.text",
                        color: .green
                    )
                }

                memoryBar(result)
            }
        }
    }

    /// Horizontal bar representing estimated memory usage.
    private func memoryBar(_ result: BenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Memory estimate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(result.memoryDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                let fraction = min(result.memoryFraction, 1.0)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(memoryColor(fraction))
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(height: 8)
        }
    }

    /// Returns a color gradient from green to red based on usage fraction.
    private func memoryColor(_ fraction: Double) -> Color {
        if fraction < 0.5 { return .green }
        if fraction < 0.75 { return .orange }
        return .red
    }

    // MARK: - Strategy Comparison

    @ViewBuilder
    private var strategyComparisonSection: some View {
        if !strategyResults.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeaderView(
                        title: "Parsing Strategy Comparison",
                        systemImage: "chart.bar.xaxis"
                    )

                    let maxThroughput = strategyResults
                        .map(\.messagesPerSecond)
                        .max() ?? 1

                    ForEach(strategyResults) { result in
                        strategyBar(result, maxValue: maxThroughput)
                    }
                }
            }
            .transition(.opacity)
        }
    }

    /// A labeled horizontal bar for one parsing strategy.
    private func strategyBar(_ result: StrategyResult, maxValue: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.name)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f msg/s", result.messagesPerSecond))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                let fraction = result.messagesPerSecond / maxValue
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(result.color)
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(height: 12)
        }
    }

    // MARK: - Benchmark Logic

    /// Runs the primary parsing benchmark with progress updates.
    private func runBenchmark() async {
        isRunning = true
        progress = 0
        benchmarkResult = nil
        let count = Int(messageCount)
        appState.log("Starting benchmark: \(count) messages", level: .info)

        let message = SampleMessages.adtA01
        let start = ContinuousClock.now
        var successCount = 0

        for i in 0..<count {
            do {
                _ = try HL7v2Message.parse(message)
                successCount += 1
            } catch {
                // Count failures but continue
            }

            // Update progress periodically to keep UI responsive
            if i % max(count / 50, 1) == 0 {
                progress = Double(i) / Double(count)
                await Task.yield()
            }
        }

        let elapsed = start.duration(to: .now)
        let totalSeconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        let msgPerSec = totalSeconds > 0 ? Double(successCount) / totalSeconds : 0

        // Estimate memory: each parsed message is roughly 2-4 KB
        let estimatedBytes = successCount * 3072

        progress = 1.0
        benchmarkResult = BenchmarkResult(
            messageCount: successCount,
            totalSeconds: totalSeconds,
            messagesPerSecond: msgPerSec,
            avgParseMilliseconds: (totalSeconds * 1000) / Double(max(successCount, 1)),
            estimatedMemoryBytes: estimatedBytes
        )

        appState.log(
            "Benchmark complete: \(String(format: "%.0f", msgPerSec)) msg/s",
            level: .success
        )
        isRunning = false
    }

    /// Compares parsing throughput across different message types.
    private func runStrategyComparison() async {
        isRunning = true
        strategyResults = []
        appState.log("Running strategy comparison…", level: .info)

        let strategies: [(String, String, Color)] = [
            ("ADT^A01 (4 segments)", SampleMessages.adtA01, .blue),
            ("ORU^R01 (6 segments)", SampleMessages.oruR01, .green),
            ("Minimal (2 segments)", SampleMessages.invalidMessage, .orange),
            ("Re-serialize round-trip", SampleMessages.adtA01, .purple)
        ]

        let iterations = max(Int(messageCount / 4), 100)

        for (name, message, color) in strategies {
            let start = ContinuousClock.now
            var successCount = 0

            for _ in 0..<iterations {
                do {
                    let parsed = try HL7v2Message.parse(message)
                    if name.contains("round-trip") {
                        // Parse → serialize → parse again
                        let serialized = try parsed.serialize()
                        _ = try HL7v2Message.parse(serialized)
                    }
                    successCount += 1
                } catch {
                    // Intentionally invalid messages may fail
                    successCount += 1
                }
            }

            let elapsed = start.duration(to: .now)
            let totalSec = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18
            let throughput = totalSec > 0 ? Double(successCount) / totalSec : 0

            strategyResults.append(StrategyResult(
                name: name,
                messagesPerSecond: throughput,
                color: color
            ))

            await Task.yield()
        }

        appState.log("Strategy comparison complete", level: .success)
        isRunning = false
    }
}

// MARK: - Metric Card

/// A compact card displaying a single performance metric.
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold().monospaced())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Data Models

/// Results from a single benchmark run.
struct BenchmarkResult: Sendable {
    let messageCount: Int
    let totalSeconds: Double
    let messagesPerSecond: Double
    let avgParseMilliseconds: Double
    let estimatedMemoryBytes: Int

    /// Human-readable memory description.
    var memoryDescription: String {
        let kb = Double(estimatedMemoryBytes) / 1024
        if kb < 1024 {
            return String(format: "%.0f KB", kb)
        }
        return String(format: "%.1f MB", kb / 1024)
    }

    /// Fraction of a 100 MB budget used (for the progress bar).
    var memoryFraction: Double {
        Double(estimatedMemoryBytes) / (100 * 1024 * 1024)
    }
}

/// Results for one parsing strategy in the comparison chart.
struct StrategyResult: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let messagesPerSecond: Double
    let color: Color
}
#endif
