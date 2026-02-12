import WidgetKit
import SwiftUI
import UIKit

private extension UIImage {
    func flattenedOnWhite(scale: CGFloat = 1.0) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func downscaledForWidget(maxDimension: CGFloat = 512) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }
        let currentMax = max(size.width, size.height)
        guard currentMax > maxDimension else { return self }

        let scaleFactor = maxDimension / currentMax
        let newSize = CGSize(width: floor(size.width * scaleFactor), height: floor(size.height * scaleFactor))
        guard newSize.width >= 1, newSize.height >= 1 else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: newSize))
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private func decodeDataURLImage(_ dataURL: String) -> UIImage? {
    let base64: String
    if let commaIndex = dataURL.firstIndex(of: ",") {
        base64 = String(dataURL[dataURL.index(after: commaIndex)...])
    } else {
        base64 = dataURL
    }
    guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else { return nil }
    return UIImage(data: data)?
        .withRenderingMode(.alwaysOriginal)
        .flattenedOnWhite(scale: 1.0)
        .downscaledForWidget(maxDimension: 512)
}

struct DOODLWidgetEntry: TimelineEntry {
    let date: Date
    let doodle: SharedWidgetDoodle?
}

struct DOODLWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DOODLWidgetEntry {
        DOODLWidgetEntry(
            date: .now,
            doodle: SharedWidgetDoodle(
                doodleId: nil,
                senderUsername: "someone",
                contentBase64: "",
                createdAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DOODLWidgetEntry) -> Void) {
        completion(DOODLWidgetEntry(date: .now, doodle: SharedWidgetStore.loadLatestDoodle()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DOODLWidgetEntry>) -> Void) {
        // Push-driven: rely on the app writing into the shared widget store.
        let entry = DOODLWidgetEntry(date: .now, doodle: SharedWidgetStore.loadLatestDoodle())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(60 * 15)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private func fetchLatestDoodleForWidget() async -> SharedWidgetDoodle? {
    guard let config = SharedWidgetStore.loadWidgetConfig() else { return nil }
    // "All sources" mode is push-driven: rely on the app writing into the shared widget store.
    if SharedWidgetStore.isAllSources(config.groupCode) {
        return nil
    }
    // Use lightweight meta fetch + on-demand content fetch to avoid statement timeouts.
    let metas: [SupabaseWidgetClient.InboxDoodle]
    do {
        metas = try await SupabaseWidgetClient.fetchInboxDoodleMetas(
            groupCode: config.groupCode,
            requesterProfileId: config.profileId,
            limit: 18
        )
    } catch {
        // Avoid falling back to `inbox_doodles_secure` here; if metas fails, rely on cached doodle.
        return nil
    }

    guard let latestFromOther = metas.first(where: { $0.senderUsername.lowercased() != config.username.lowercased() }) else {
        return nil
    }

    var content = latestFromOther.contentBase64
    if content == nil {
        content = try? await SupabaseWidgetClient.fetchDoodleContent(
            groupCode: config.groupCode,
            requesterProfileId: config.profileId,
            doodleId: latestFromOther.id
        )
    }
    guard let content else { return nil }

    let doodle = SharedWidgetDoodle(
        doodleId: latestFromOther.id,
        senderUsername: latestFromOther.senderUsername,
        contentBase64: content,
        createdAt: latestFromOther.createdAt ?? Date()
    )
    SharedWidgetStore.saveLatestDoodle(doodle)
    return doodle
}

private enum SupabaseWidgetClient {
    private static let baseURL = URL(string: "https://jgunrdhmipqltddbnnyb.supabase.co")!
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpndW5yZGhtaXBxbHRkZGJubnliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MjQzMzQsImV4cCI6MjA4MTMwMDMzNH0.AGUY1vCSojY15_8EN5kvdJ2ApX6RDieSQOC90iaTPq8"

    private static var restURL: URL { baseURL.appendingPathComponent("rest/v1") }

    struct InboxDoodle: Identifiable {
        let id: String
        let contentBase64: String?
        let senderUsername: String
        let createdAt: Date?
    }

    static func fetchInboxDoodles(groupCode: String, requesterProfileId: String, limit: Int) async throws -> [InboxDoodle] {
        let url = restURL.appendingPathComponent("rpc/inbox_doodles_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_limit": limit
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        struct Row: Decodable {
            let doodle_id: String
            let content_base64: String?
            let sender_username: String
            let created_at: String?
        }

        let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
        return rows.map { row in
            InboxDoodle(
                id: row.doodle_id,
                contentBase64: row.content_base64,
                senderUsername: row.sender_username,
                createdAt: row.created_at.flatMap(parseISO8601)
            )
        }
    }

    static func fetchInboxDoodleMetas(groupCode: String, requesterProfileId: String, limit: Int) async throws -> [InboxDoodle] {
        let url = restURL.appendingPathComponent("rpc/inbox_doodle_metas_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_limit": limit
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        struct Row: Decodable {
            let doodle_id: String
            let sender_username: String
            let created_at: String?
        }

        let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
        return rows.map { row in
            InboxDoodle(
                id: row.doodle_id,
                contentBase64: nil,
                senderUsername: row.sender_username,
                createdAt: row.created_at.flatMap(parseISO8601)
            )
        }
    }

    static func fetchDoodleContent(groupCode: String, requesterProfileId: String, doodleId: String) async throws -> String? {
        let url = restURL.appendingPathComponent("rpc/doodle_contents_secure")
        let body: [String: Any] = [
            "p_code": groupCode.lowercased(),
            "p_requester_profile_id": requesterProfileId,
            "p_doodle_ids": [doodleId]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        struct Row: Decodable {
            let doodle_id: String
            let content_base64: String?
        }

        let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
        return rows.first(where: { $0.doodle_id == doodleId })?.content_base64
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}

struct DOODLWidgetView: View {
    let entry: DOODLWidgetEntry

    var body: some View {
        let senderLabel = entry.doodle.map { $0.senderUsername.lowercased() }

        ZStack(alignment: .bottom) {
            Color.clear

            if entry.doodle == nil {
                VStack(spacing: 8) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.black.opacity(0.12))
                    Text("no doodls yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.45))
                }
            }

            if let senderLabel {
                Text(senderLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

struct DOODLWidget: Widget {
    static let kind = "doodl.widget.latest"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DOODLWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                DOODLWidgetView(entry: entry)
                    .environment(\.colorScheme, .light)
                    .containerBackground(for: .widget) {
                        ZStack {
                            Color.white
                            if let doodle = entry.doodle,
                               let uiImage = decodeDataURLImage(doodle.contentBase64) {
                                Image(uiImage: uiImage)
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                    }
            } else {
                DOODLWidgetView(entry: entry)
                    .environment(\.colorScheme, .light)
                    .background(Color.white)
            }
        }
        .configurationDisplayName("doodl.")
        .description("shows the latest doodl from your group.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#if canImport(PreviewsMacros)
#Preview(as: .systemSmall) {
    DOODLWidget()
} timeline: {
    DOODLWidgetEntry(date: .now, doodle: SharedWidgetStore.loadLatestDoodle())
}
#endif
