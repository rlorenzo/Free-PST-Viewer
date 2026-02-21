import AppKit
@preconcurrency import MAPI
import SwiftUI
@preconcurrency import PstReader

struct EmailDetailView: View {
    @ObservedObject var viewModel: EmailDetailViewModel
    let attachmentService: AttachmentService

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading email...")
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.detailedMessage {
                EmailContentView(
                    message: message,
                    attachmentService: attachmentService
                )
            } else {
                Text("Select an email to view its contents")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct EmailContentView: View {
    let message: PstFile.Message
    let attachmentService: AttachmentService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EmailHeaderView(
                message: message,
                attachmentService: attachmentService
            )
            .padding()

            Divider()

            EmailBodyView(
                message: message,
                attachments: message.attachments
            )
        }
    }
}

struct EmailHeaderView: View {
    let message: PstFile.Message
    let attachmentService: AttachmentService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.subjectText ?? "(No Subject)")
                .font(.title2)
                .fontWeight(.semibold)
                .textSelection(.enabled)

            headerRow("From:", value: message.senderDisplayString)
            headerRow("To:", value: message.toRecipients)
            if let cc = message.ccRecipients, !cc.isEmpty {
                headerRow("Cc:", value: cc)
            }
            if let bcc = message.bccRecipients, !bcc.isEmpty {
                headerRow("Bcc:", value: bcc)
            }
            if let date = message.date {
                headerRow("Date:", value: formatDate(date))
            }

            if !message.attachments.isEmpty {
                AttachmentListView(
                    attachments: message.attachments,
                    attachmentService: attachmentService
                )
            }

            FullHeaderSection(message: message)
        }
    }

    private func headerRow(_ label: String, value: String?) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            Text(value ?? "Unknown")
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct FullHeaderSection: View {
    let message: PstFile.Message
    @State private var showFullHeaders = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                toggleButton
                Spacer()
                if showFullHeaders { copyButton }
            }

            if showFullHeaders {
                headerContent
            }
        }
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showFullHeaders.toggle()
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: showFullHeaders
                    ? "chevron.down" : "chevron.right")
                Text(showFullHeaders
                    ? "Hide Headers" : "Show Headers")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showFullHeaders
            ? "Hide full email headers"
            : "Show full email headers")
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                fullHeaderText, forType: .string
            )
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "doc.on.doc")
                Text("Copy Headers")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy email headers to clipboard")
    }

    private var headerContent: some View {
        ScrollView {
            Text(fullHeaderText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
    }

    private var fullHeaderText: String {
        if let headers = message.transportMessageHeaders,
           !headers.isEmpty {
            return headers
        }
        return buildMapiHeaders()
    }

    private func buildMapiHeaders() -> String {
        var lines: [String] = []
        if let id = message.internetMessageId {
            lines.append("Message-ID: \(id)")
        }
        if let imp = message.importance {
            lines.append("Importance: \(formatImportance(imp))")
        }
        if let flags = message.messageFlags {
            let desc = formatFlags(flags)
            if !desc.isEmpty {
                lines.append("Flags: \(desc)")
            }
        }
        if let cls = message.messageClass {
            lines.append("Message-Class: \(cls)")
        }
        if lines.isEmpty {
            return "No header information available."
        }
        return lines.joined(separator: "\n")
    }
}

private func formatImportance(_ importance: MessageImportance) -> String {
    switch importance {
    case .low: return "Low"
    case .normal: return "Normal"
    case .high: return "High"
    }
}

private func formatFlags(_ flags: MessageFlags) -> String {
    var parts: [String] = []
    if flags.contains(.read) { parts.append("Read") }
    if flags.contains(.unsent) { parts.append("Unsent") }
    if flags.contains(.hasAttachment) {
        parts.append("Has Attachments")
    }
    if flags.contains(.fromMe) { parts.append("From Me") }
    if flags.contains(.unmodified) { parts.append("Unmodified") }
    if flags.contains(.submitted) { parts.append("Submitted") }
    return parts.joined(separator: ", ")
}

struct AttachmentListView: View {
    let attachments: [PstFile.Attachment]
    let attachmentService: AttachmentService
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Attachments:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(
                    Array(attachments.enumerated()),
                    id: \.offset
                ) { _, attachment in
                    AttachmentBadge(
                        attachment: attachment,
                        onSave: { saveAttachment(attachment) },
                        onOpen: { openAttachment(attachment) }
                    )
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func saveAttachment(_ att: PstFile.Attachment) {
        Task {
            errorMessage = nil
            do {
                try await attachmentService
                    .saveAttachmentWithPanel(att)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openAttachment(_ att: PstFile.Attachment) {
        Task {
            errorMessage = nil
            do {
                try await attachmentService
                    .openAttachment(att)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct AttachmentBadge: View {
    let attachment: PstFile.Attachment
    let onSave: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "paperclip")
                .font(.caption)
            Text(attachment.filename ?? "Untitled")
                .font(.caption)
                .lineLimit(1)
            if let size = attachment.sizeInBytes {
                Text("(\(formatByteCount(size)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
        .contextMenu {
            Button("Save As...") { onSave() }
            Button("Open") { onOpen() }
        }
    }
}

/// Simple flow layout for attachment badges.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + rowHeight)
        )
    }
}
