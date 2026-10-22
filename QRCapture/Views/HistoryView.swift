import SwiftUI

struct HistoryView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var history: HistoryStore
    @State private var search = ""
    @State private var selectedID: UUID?
    @State private var confirmClear = false

    private var filteredRecords: [ScanRecord] {
        guard !search.isEmpty else { return history.records }
        return history.records.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    private var selectedRecord: ScanRecord? {
        history.records.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { controller.scanScreen() } label: {
                    Label("Сканировать", systemImage: "qrcode.viewfinder")
                }
                Button { controller.scanClipboard() } label: {
                    Label("Получить из буфера", systemImage: "clipboard")
                }
                Spacer()
                if controller.isBusy { ProgressView().controlSize(.small) }
                if let feedback = controller.feedback {
                    Text(feedback).font(.caption).foregroundStyle(.green).accessibilityAddTraits(.updatesFrequently)
                }
            }
            .disabled(controller.isBusy)
            .padding()
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Поиск по содержимому", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Очистить поиск")
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.bottom, 12)
            Divider()
            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? "История пуста" : "Ничего не найдено",
                    systemImage: search.isEmpty ? "qrcode" : "magnifyingglass",
                    description: Text(search.isEmpty ? "Сканируйте QR-код — его текст появится здесь." : "Попробуйте другой запрос.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedID) {
                    ForEach(filteredRecords) { record in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.scannedAt, format: .dateTime.day().month().year().hour().minute().second())
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(record.text).lineLimit(2).truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button { controller.copy(record.text) } label: { Image(systemName: "doc.on.doc") }
                                .buttonStyle(.borderless)
                                .help("Копировать исходный текст")
                                .accessibilityLabel("Копировать текст QR-кода")
                        }
                        .padding(.vertical, 5)
                        .tag(record.id)
                        .contextMenu {
                            Button("Копировать") { controller.copy(record.text) }
                            Button("Удалить", role: .destructive) { controller.remove(record) }
                        }
                    }
                }
                .listStyle(.inset)
            }
            if let selectedRecord {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Полное содержимое").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Копировать") { controller.copy(selectedRecord.text) }
                        Button(role: .destructive) { controller.remove(selectedRecord) } label: {
                            Image(systemName: "trash")
                        }
                        .help("Удалить запись")
                    }
                    ScrollView {
                        Text(selectedRecord.text)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 130)
                }
                .padding()
            }
            Divider()
            HStack {
                Text("\(history.records.count) / 100").font(.caption).foregroundStyle(.secondary)
                Button("Очистить историю…", role: .destructive) { confirmClear = true }
                    .disabled(history.records.isEmpty)
                Spacer()
                Button { controller.showSettings() } label: { Image(systemName: "gearshape") }
                    .help("Настройки")
                    .accessibilityLabel("Настройки")
                Button("Выход") { NSApplication.shared.terminate(nil) }
            }
            .controlSize(.small)
            .padding()
        }
        .frame(minWidth: 440, minHeight: 380)
        .confirmationDialog("Удалить всю историю?", isPresented: $confirmClear) {
            Button("Удалить все записи", role: .destructive) { controller.clearHistory() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Восстановить записи будет невозможно.")
        }
    }
}
