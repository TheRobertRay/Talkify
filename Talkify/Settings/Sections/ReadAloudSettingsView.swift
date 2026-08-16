import SwiftUI

/// Lewis is the single deliberate Read Aloud voice. There is no engine,
/// download, or model choice for Robert to maintain after installation.
struct ReadAloudSettingsView: View {
  @Bindable var settings: AppSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SettingsCard(title: "Voice") {
        SettingsRow(
          title: "Lewis",
          description: "A lifelike British male voice powered locally by Kokoro"
        ) {
          Text("Installed")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.accent)
        }
      }

      SettingsCard(title: "Privacy") {
        SettingsRow(
          title: "Entirely on this Mac",
          description: "Selected text becomes audio in memory and is never saved or sent online"
        ) {
          Image(systemName: "checkmark.shield.fill")
            .foregroundStyle(SettingsTheme.accent)
        }
      }
    }
  }
}
