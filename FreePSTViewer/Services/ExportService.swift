import Foundation
@preconcurrency import PstReader

/// Handles exporting emails and saving attachments to disk.
/// The caller is responsible for loading message details (via
/// `PSTParserService.getMessageDetails`) before calling `exportEmail`.
/// The service works with whatever data is available on the message.
struct ExportService {

    // MARK: - Public API

    func exportEmail(
        _ message: PstFile.Message,
        to url: URL,
        format: ExportFormat
    ) throws {
        let data: Data
        switch format {
        case .eml:
            data = try buildEml(from: message)
        case .txt:
            data = try buildTxt(from: message)
        }
        try data.write(to: url, options: .atomic)
        setFileTimestamps(url: url, date: message.date)
    }

    func saveAttachment(
        _ attachment: PstFile.Attachment,
        to url: URL
    ) throws {
        guard let fileData = attachment.fileData else {
            throw PSTViewerError.exportError(
                "Attachment has no data."
            )
        }
        try fileData.write(to: url, options: .atomic)
    }

    // MARK: - EML Builder

    private func buildEml(
        from message: PstFile.Message
    ) throws -> Data {
        var output = buildEmlHeaders(from: message)
        appendEmlBody(to: &output, from: message)

        guard let data = output.data(using: .utf8) else {
            throw PSTViewerError.exportError(
                "Failed to encode email as UTF-8."
            )
        }
        return data
    }

    private func buildEmlHeaders(
        from message: PstFile.Message
    ) -> String {
        var output = ""
        if let headers = message.transportMessageHeaders,
           !headers.isEmpty {
            output += headers
            if !output.hasSuffix("\r\n\r\n") {
                if output.hasSuffix("\r\n") {
                    output += "\r\n"
                } else if output.hasSuffix("\n") {
                    output += "\n"
                } else {
                    output += "\r\n\r\n"
                }
            }
        } else {
            output += buildSyntheticHeaders(from: message)
            output += "\r\n"
        }
        return output
    }

    private func appendEmlBody(
        to output: inout String,
        from message: PstFile.Message
    ) {
        let bodyText = message.bodyText.flatMap {
            $0.isEmpty ? nil : $0
        }
        let bodyHtml = message.bodyHtmlString.flatMap {
            $0.isEmpty ? nil : $0
        }

        if let text = bodyText, let html = bodyHtml {
            let boundary = generateBoundary()
            output = replaceContentType(
                in: output,
                with: "multipart/alternative; "
                    + "boundary=\"\(boundary)\""
            )
            output += "--\(boundary)\r\n"
            output += "Content-Type: text/plain; charset=\"utf-8\"\r\n"
            output += "Content-Transfer-Encoding: quoted-printable\r\n\r\n"
            output += quotedPrintableEncode(text)
            output += "\r\n\r\n--\(boundary)\r\n"
            output += "Content-Type: text/html; charset=\"utf-8\"\r\n"
            output += "Content-Transfer-Encoding: quoted-printable\r\n\r\n"
            output += quotedPrintableEncode(html)
            output += "\r\n\r\n--\(boundary)--\r\n"
        } else if let html = bodyHtml {
            output = replaceContentType(
                in: output,
                with: "text/html; charset=\"utf-8\""
            )
            output += html
            output += "\r\n"
        } else if let text = bodyText {
            output = replaceContentType(
                in: output,
                with: "text/plain; charset=\"utf-8\""
            )
            output += text
            output += "\r\n"
        }
    }

    private func buildSyntheticHeaders(
        from message: PstFile.Message
    ) -> String {
        var headers = ""
        headers += "MIME-Version: 1.0\r\n"

        if let from = formatSender(message) {
            headers += "From: \(from)\r\n"
        }
        if let to = message.toRecipients {
            headers += "To: \(to)\r\n"
        }
        if let cc = message.ccRecipients, !cc.isEmpty {
            headers += "Cc: \(cc)\r\n"
        }
        if let bcc = message.bccRecipients, !bcc.isEmpty {
            headers += "Bcc: \(bcc)\r\n"
        }
        if let subject = message.subjectText {
            headers += "Subject: \(subject)\r\n"
        }
        if let date = message.date {
            headers += "Date: \(rfc2822Date(date))\r\n"
        }
        if let msgId = message.internetMessageId {
            headers += "Message-ID: \(msgId)\r\n"
        }
        headers += "Content-Type: text/plain; "
            + "charset=\"utf-8\"\r\n"
        return headers
    }

    /// Replaces Content-Type in headers, or appends if
    /// the headers came from transportMessageHeaders and
    /// already include one.
    private func replaceContentType(
        in text: String,
        with newType: String
    ) -> String {
        let lines = text.components(separatedBy: "\r\n")
        var result: [String] = []
        var replaced = false
        var skipContinuation = false

        for line in lines {
            if skipContinuation {
                if line.hasPrefix(" ") || line.hasPrefix("\t") {
                    continue
                }
                skipContinuation = false
            }
            if line.lowercased().hasPrefix("content-type:") {
                result.append(
                    "Content-Type: \(newType)"
                )
                replaced = true
                skipContinuation = true
            } else {
                result.append(line)
            }
        }
        var output = result.joined(separator: "\r\n")
        if !replaced {
            let sep = "\r\n\r\n"
            if let range = output.range(of: sep) {
                output.insert(
                    contentsOf: "Content-Type: \(newType)\r\n",
                    at: range.lowerBound
                )
            }
        }
        return output
    }

    // MARK: - TXT Builder

    private func buildTxt(
        from message: PstFile.Message
    ) throws -> Data {
        var output = ""

        if let subject = message.subjectText {
            output += "Subject: \(subject)\n"
        }
        if let from = formatSender(message) {
            output += "From: \(from)\n"
        }
        if let to = message.toRecipients {
            output += "To: \(to)\n"
        }
        if let cc = message.ccRecipients, !cc.isEmpty {
            output += "Cc: \(cc)\n"
        }
        if let bcc = message.bccRecipients, !bcc.isEmpty {
            output += "Bcc: \(bcc)\n"
        }
        if let date = message.date {
            let fmt = DateFormatter()
            fmt.dateStyle = .full
            fmt.timeStyle = .long
            output += "Date: \(fmt.string(from: date))\n"
        }

        output += "\n"

        if let body = message.bodyText, !body.isEmpty {
            output += body
        } else if let html = message.bodyHtmlString,
                  !html.isEmpty {
            output += stripHtml(html)
        }

        output += "\n"

        guard let data = output.data(using: .utf8) else {
            throw PSTViewerError.exportError(
                "Failed to encode email as UTF-8."
            )
        }
        return data
    }

    // MARK: - Helpers

    private func formatSender(
        _ message: PstFile.Message
    ) -> String? {
        if let name = message.senderDisplayName,
           let addr = message.senderAddress {
            return "\(name) <\(addr)>"
        }
        return message.senderDisplayName
            ?? message.senderAddress
    }

    private static let rfc2822Formatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return fmt
    }()

    func rfc2822Date(_ date: Date) -> String {
        Self.rfc2822Formatter.string(from: date)
    }

    private func generateBoundary() -> String {
        let uuid = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
        return "----=_Part_\(uuid)"
    }

    private func setFileTimestamps(
        url: URL,
        date: Date?
    ) {
        guard let date = date else { return }
        try? FileManager.default.setAttributes(
            [
                .creationDate: date,
                .modificationDate: date
            ],
            ofItemAtPath: url.path
        )
    }

    /// Produces a sanitized filename from a subject line.
    static func suggestedFilename(
        for message: PstFile.Message,
        format: ExportFormat
    ) -> String {
        let ext = format == .eml ? "eml" : "txt"
        let raw = message.subjectText ?? "Untitled"
        let sanitized = raw
            .replacingOccurrences(
                of: "[/\\\\:*?\"<>|]",
                with: "_",
                options: .regularExpression
            )
            .prefix(100)
        return "\(sanitized).\(ext)"
    }
}

// MARK: - Private Encoding Helpers

private func stripHtml(_ html: String) -> String {
    var text = html
    let breakPattern =
        "<br\\s*/?>|</p>|</div>|</tr>|</li>"
    if let regex = try? NSRegularExpression(
        pattern: breakPattern,
        options: .caseInsensitive
    ) {
        text = regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "\n"
        )
    }
    if let tagRegex = try? NSRegularExpression(
        pattern: "<[^>]+>",
        options: []
    ) {
        text = tagRegex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
    }
    text = text
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&nbsp;", with: " ")
    return text
}

private func quotedPrintableEncode(
    _ string: String
) -> String {
    guard let data = string.data(using: .utf8) else {
        return string
    }
    var result = ""
    var lineLen = 0
    for byte in data {
        let char = Character(UnicodeScalar(byte))
        if byte == 0x0D || byte == 0x0A {
            result.append(char)
            lineLen = 0
        } else if byte == 0x09
                    || (byte >= 0x20 && byte <= 0x7E
                        && byte != 0x3D) {
            if lineLen >= 75 {
                result += "=\r\n"
                lineLen = 0
            }
            result.append(char)
            lineLen += 1
        } else {
            let encoded = String(
                format: "=%02X", byte
            )
            if lineLen + 3 > 76 {
                result += "=\r\n"
                lineLen = 0
            }
            result += encoded
            lineLen += 3
        }
    }
    return result
}
