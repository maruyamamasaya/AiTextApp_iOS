import SwiftUI
import WidgetKit

private struct QuickCaptureEntry: TimelineEntry {
    let date: Date
}

private struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> Void) {
        completion(QuickCaptureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        completion(Timeline(entries: [QuickCaptureEntry(date: Date())], policy: .never))
    }
}

private struct QuickCaptureWidgetView: View {
    var body: some View {
        widgetContent
            .widgetURL(QuickCaptureRoute.url)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Quick Captureを開く")
            .accessibilityHint("Thoughtの入力画面を開きます")
    }

    @ViewBuilder
    private var widgetContent: some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(.background, for: .widget)
        } else {
            content
                .background(Color(uiColor: .systemBackground))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Thought", systemImage: "text.bubble")
                .font(.headline)

            Text("今なに考えてる？")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Label("書く", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(.tint)
        }
        .padding()
    }
}

@main
struct QuickCaptureWidget: Widget {
    let kind = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { _ in
            QuickCaptureWidgetView()
        }
        .configurationDisplayName("Thoughtを書く")
        .description("Quick Captureを開いて、すぐにThoughtを書けます。")
        .supportedFamilies([.systemSmall])
    }
}
