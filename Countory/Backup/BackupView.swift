import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var exportDocument: BackupDocument?
    @State private var exportFilename = "Countory-backup"
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isReading = false
    @State private var pendingBackup: CountoryBackup?
    @State private var importSummary: BackupService.ImportSummary?
    @State private var importFilename = ""
    @State private var isShowingMessage = false
    @State private var messageTitle = ""
    @State private var message = ""

    private let backgroundColor = Color(red: 0.93, green: 0.89, blue: 0.84)
    private let accentColor = Color(red: 0.36, green: 0.2, blue: 0.12)

    var body: some View {
        NavigationStack {
            Form {
                if let backup = pendingBackup, let summary = importSummary {
                    Section {
                        LabeledContent("ファイル", value: importFilename)
                        LabeledContent("書き出し日時") {
                            Text(backup.exportedAt, format: .dateTime.year().month().day().hour().minute())
                        }
                        LabeledContent("ファイル内の商品", value: "\(backup.items.count)件")
                        LabeledContent("ファイル内のカテゴリ", value: "\(backup.categories.count)件")
                        LabeledContent("追加する商品", value: "\(summary.addedItems)件")
                        LabeledContent("取り込み済みの商品", value: "\(summary.skippedItems)件")
                        LabeledContent("追加するカテゴリ", value: "\(summary.addedCategories)件")
                        Button("この内容を取り込む", action: importBackup)
                            .accessibilityIdentifier("confirmImport")
                        Button("取り込みをやめる", role: .cancel) {
                            pendingBackup = nil
                            importSummary = nil
                        }
                    } header: {
                        Text("取り込み内容の確認")
                    } footer: {
                        Text("現在のデータに追加します。取り込み済みの商品は上書きしません。同名でも別々に登録した商品は追加されます。")
                    }
                } else {
                    transferOptions
                }
            }
            .scrollContentBackground(.hidden)
            .background(backgroundColor)
            .navigationTitle("データ移行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(isReading)
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                switch result {
                case .success:
                    showMessage("書き出し完了", "バックアップを保存しました。新しいiPhoneでこのファイルを取り込んでください。")
                case .failure(let error):
                    showError(error)
                }
                exportDocument = nil
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    readBackup(from: url)
                case .failure(let error):
                    showError(error)
                }
            }
            .alert(messageTitle, isPresented: $isShowingMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(message)
            }
            .interactiveDismissDisabled(isReading)
            .tint(accentColor)
        }
    }

    @ViewBuilder
    private var transferOptions: some View {
        Section {
            Text("商品・数量・メモ・登録日時・カテゴリをまとめて、新しいiPhoneへ移せます。")
        }

        Section {
            Button(action: exportBackup) {
                Label("バックアップを書き出す", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("exportBackup")
            .disabled(isReading)
        } header: {
            Text("旧iPhoneで書き出す")
        } footer: {
            Text("すべてのデータを保存します。iCloud Driveに保存するか、保存後に「ファイル」アプリからAirDropで送ってください。")
        }

        Section {
            Button {
                isImporting = true
            } label: {
                Label("バックアップを選ぶ", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("selectBackup")
            .disabled(isReading)
            if isReading {
                ProgressView("バックアップを読み込み中…")
            }
        } header: {
            Text("新しいiPhoneで取り込む")
        } footer: {
            Text("カウントリーから書き出したJSONファイルを選びます。取り込む前に内容を確認できます。")
        }
    }

    private func exportBackup() {
        do {
            let backup = try BackupService.export(from: modelContext)
            exportDocument = BackupDocument(data: try backup.encoded())
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            exportFilename = "Countory-\(formatter.string(from: backup.exportedAt))"
            isExporting = true
        } catch {
            showError(error)
        }
    }

    private func readBackup(from url: URL) {
        isReading = true
        Task {
            defer { isReading = false }
            do {
                let backup = try await Task.detached(priority: .userInitiated) {
                    try CountoryBackup.read(from: url)
                }.value
                importSummary = try BackupService.preview(backup, in: modelContext)
                importFilename = url.lastPathComponent
                pendingBackup = backup
            } catch {
                showError(error)
            }
        }
    }

    private func importBackup() {
        guard let backup = pendingBackup else { return }
        do {
            let summary = try BackupService.restore(backup, into: modelContext)
            pendingBackup = nil
            importSummary = nil
            showMessage(
                "取り込み完了",
                "商品を\(summary.addedItems)件、カテゴリを\(summary.addedCategories)件追加しました。"
                    + "取り込み済みの商品\(summary.skippedItems)件は変更していません。"
            )
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        guard (error as NSError).code != NSUserCancelledError else { return }
        showMessage("データ移行に失敗しました", error.localizedDescription)
    }

    private func showMessage(_ title: String, _ text: String) {
        messageTitle = title
        message = text
        isShowingMessage = true
    }
}
