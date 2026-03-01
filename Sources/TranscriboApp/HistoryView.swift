import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse) private var records: [TranscriptionRecord]
    @State private var searchText = ""
    @Environment(\.modelContext) private var modelContext

    private var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty { return records }
        return records.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transcriptions…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.bar)

            Divider()

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "No Transcriptions",
                    systemImage: "waveform.slash",
                    description: Text(
                        searchText.isEmpty
                            ? "Your transcription history will appear here."
                            : "No results for \"\(searchText)\"."
                    )
                )
            } else {
                List {
                    ForEach(filteredRecords) { record in
                        HistoryRow(record: record)
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .toolbar {
            ToolbarItem {
                Button("Clear All", role: .destructive) {
                    clearAll()
                }
                .disabled(records.isEmpty)
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRecords[index])
        }
    }

    private func clearAll() {
        for record in records {
            modelContext.delete(record)
        }
    }
}

struct HistoryRow: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text(record.timestamp, style: .date)
                Text(record.sourceAppName)
                Text(String(format: "%.1fs", record.durationSeconds))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.text, forType: .string)
            }
        }
    }
}
