import SwiftUI
import AppKit

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDocument: HelpDocument
    @State private var searchText = ""
    
    init(document: HelpDocument = .userGuide) {
        _selectedDocument = State(initialValue: document)
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with document list
            List(HelpDocument.allCases, selection: $selectedDocument) { doc in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.title)
                            .font(.body)
                        Text(doc.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: doc.icon)
                        .foregroundColor(doc.color)
                }
                .tag(doc)
            }
            .navigationTitle("Help Topics")
            .frame(minWidth: 250)
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Header with title and search
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedDocument.title)
                                .font(.title)
                                .fontWeight(.bold)
                            Text(selectedDocument.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search in document...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
                
                // Document content - use native NSTextView with its own scrolling
                DocumentContentView(
                    document: selectedDocument,
                    searchText: searchText
                )
            }
        }
        .frame(minWidth: 900, minHeight: 650)
    }
}

// MARK: - Document Content View

struct DocumentContentView: NSViewRepresentable {
    let document: HelpDocument
    let searchText: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.autoresizingMask = [.width]
        
        // Configure text container for wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Load content
        guard let content = loadDocumentContent() else {
            textView.string = "Unable to load document content"
            return
        }
        
        let processedContent = highlightedContent(content)
        
        // Try to render markdown with better formatting
        if let attributedText = renderMarkdown(processedContent) {
            textView.textStorage?.setAttributedString(attributedText)
        } else {
            // Fallback to plain text
            textView.string = processedContent
            textView.font = .systemFont(ofSize: 14)
            textView.textColor = .textColor
        }
    }
    
    private func renderMarkdown(_ markdown: String) -> NSAttributedString? {
        // First, let's try a simpler approach - use Down or just render as plain text with manual formatting
        // The issue is that Apple's markdown parser collapses paragraphs
        
        // Manual simple markdown rendering for better control
        let mutableAttr = NSMutableAttributedString()
        
        // Split into lines
        let lines = markdown.components(separatedBy: .newlines)
        
        // Paragraph style
        let baseParagraphStyle = NSMutableParagraphStyle()
        baseParagraphStyle.lineSpacing = 3
        baseParagraphStyle.paragraphSpacing = 10
        
        let headerParagraphStyle = NSMutableParagraphStyle()
        headerParagraphStyle.lineSpacing = 3
        headerParagraphStyle.paragraphSpacing = 14
        headerParagraphStyle.paragraphSpacingBefore = 8
        
        var i = 0
        while i < lines.count {
            var line = lines[i]
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: baseParagraphStyle
            ]
            
            // Check for headers
            if line.hasPrefix("# ") {
                line = String(line.dropFirst(2))
                attributes[.font] = NSFont.boldSystemFont(ofSize: 24)
                attributes[.paragraphStyle] = headerParagraphStyle
            } else if line.hasPrefix("## ") {
                line = String(line.dropFirst(3))
                attributes[.font] = NSFont.boldSystemFont(ofSize: 20)
                attributes[.paragraphStyle] = headerParagraphStyle
            } else if line.hasPrefix("### ") {
                line = String(line.dropFirst(4))
                attributes[.font] = NSFont.systemFont(ofSize: 17, weight: .semibold)
                attributes[.paragraphStyle] = headerParagraphStyle
            } else if line.hasPrefix("---") || line.hasPrefix("___") {
                // Horizontal rule - skip
                i += 1
                continue
            } else {
                // Regular text
                attributes[.font] = NSFont.systemFont(ofSize: 14)
                
                // Handle bold **text**
                line = line.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
                // TODO: Actually apply bold formatting - for now just remove markers
            }
            
            // Add the line
            if !line.isEmpty || i == 0 || i == lines.count - 1 {
                mutableAttr.append(NSAttributedString(string: line + "\n", attributes: attributes))
            } else {
                // Empty line - add extra spacing
                mutableAttr.append(NSAttributedString(string: "\n", attributes: attributes))
            }
            
            i += 1
        }
        
        return mutableAttr
    }
    
    private func loadDocumentContent() -> String? {
        // Try to load from app bundle resources first
        if let url = Bundle.main.url(forResource: document.resourceName, withExtension: "md"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        
        // Fallback: try to load from project directory (for development)
        guard let bundlePath = Bundle.main.resourcePath else { return nil }
        let docPath = bundlePath + "/../../../" + document.filename
        return try? String(contentsOfFile: docPath, encoding: .utf8)
    }
    
    private func highlightedContent(_ content: String) -> String {
        guard !searchText.isEmpty else { return content }
        
        // Simple highlight - wrap matching text in markdown bold
        let pattern = NSRegularExpression.escapedPattern(for: searchText)
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(content.startIndex..., in: content)
            return regex.stringByReplacingMatches(
                in: content,
                range: range,
                withTemplate: "**$0**"
            )
        }
        return content
    }
}

// MARK: - Help Document Model

enum HelpDocument: String, CaseIterable, Identifiable {
    case quickStart = "quick_start"
    case userGuide = "user_guide"
    case settingsReference = "settings_reference"
    case readme = "readme"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .quickStart: return "Quick Start Guide"
        case .userGuide: return "User Guide"
        case .settingsReference: return "Settings Reference"
        case .readme: return "About AirCapture"
        }
    }
    
    var subtitle: String {
        switch self {
        case .quickStart: return "Get started in 5 minutes"
        case .userGuide: return "Complete documentation"
        case .settingsReference: return "Detailed settings reference"
        case .readme: return "Overview and features"
        }
    }
    
    var icon: String {
        switch self {
        case .quickStart: return "bolt.circle.fill"
        case .userGuide: return "book.fill"
        case .settingsReference: return "gearshape.fill"
        case .readme: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .quickStart: return .orange
        case .userGuide: return .blue
        case .settingsReference: return .purple
        case .readme: return .green
        }
    }
    
    var filename: String {
        switch self {
        case .quickStart: return "QUICK_START.md"
        case .userGuide: return "USER_GUIDE.md"
        case .settingsReference: return "SETTINGS_REFERENCE.md"
        case .readme: return "README.md"
        }
    }
    
    var resourceName: String {
        switch self {
        case .quickStart: return "QUICK_START"
        case .userGuide: return "USER_GUIDE"
        case .settingsReference: return "SETTINGS_REFERENCE"
        case .readme: return "README"
        }
    }
}

// MARK: - Preview

#Preview {
    HelpView()
}
