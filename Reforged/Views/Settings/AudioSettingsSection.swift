import SwiftUI

struct AudioSettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Playback Speed
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Playback Speed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Spacer()

                    Text(settings.playbackSpeed.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }

                HStack(spacing: 8) {
                    ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                        SpeedButton(
                            speed: speed,
                            isSelected: settings.playbackSpeed == speed
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.playbackSpeed = speed
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Skip Interval
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Skip Interval")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Spacer()

                    Text(settings.skipInterval.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }

                HStack(spacing: 8) {
                    ForEach(SkipInterval.allCases, id: \.self) { interval in
                        SkipIntervalButton(
                            interval: interval,
                            isSelected: settings.skipInterval == interval
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.skipInterval = interval
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Continue Audio on Navigate
            SettingsToggleRow(
                title: "Continue Audio in Background",
                subtitle: "Keep playing audio when navigating away from the Bible view",
                isOn: $settings.continueAudioOnNavigate
            )

            SettingsDivider()

            // Audio Controls Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                    Text("Audio Controls")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                Text("Tap the speaker icon in the Bible view to access audio playback. You can listen while reading or use audio-only mode.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineSpacing(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.reforgedNavy.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.vertical, 10)

            SettingsDivider()

            // Reset Button
            SettingsButtonRow(
                title: "Reset Audio Settings",
                icon: "arrow.counterclockwise",
                color: .reforgedCoral
            ) {
                withAnimation {
                    settings.resetAudioSettings()
                }
            }
        }
    }
}

// MARK: - Speed Button

struct SpeedButton: View {
    let speed: PlaybackSpeed
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(speed.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skip Interval Button

struct SkipIntervalButton: View {
    let interval: SkipInterval
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(interval.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        AudioSettingsSection()
            .padding()
    }
}
