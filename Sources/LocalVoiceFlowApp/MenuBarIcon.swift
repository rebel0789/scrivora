import AppKit
import SwiftUI
import LocalVoiceFlowCore

struct ScrivoraMenuBarLabel: View {
    var runtimeState: DictationRuntimeState

    var body: some View {
        Image(nsImage: ScrivoraMenuBarIcon.templateImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 18, height: 18)
            .padding(.vertical, 2)
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch runtimeState {
        case .listening, .speechDetected, .partialTranscription:
            "\(AppBrand.productName), dictation active"
        default:
            AppBrand.productName
        }
    }
}

enum ScrivoraMenuBarIcon {
    static var templateImage: NSImage {
        if let image = loadBundledTemplateImage() {
            return image
        }

        let fallback = NSImage(systemSymbolName: "waveform", accessibilityDescription: AppBrand.productName)
            ?? NSImage(size: NSSize(width: 24, height: 24))
        fallback.isTemplate = true
        fallback.size = NSSize(width: 24, height: 24)
        return fallback
    }

    private static func loadBundledTemplateImage() -> NSImage? {
        guard
            let url = Bundle.main.url(forResource: "ScrivoraMenuBarTemplate", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 24, height: 24)
        return image
    }
}
