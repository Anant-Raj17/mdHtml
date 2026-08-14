# MdHtml

A lightweight native macOS app for browsing a folder of Markdown and HTML files. It renders the output (not source) in a fast WebKit preview, and lets you edit Markdown files when needed.

## Features

- Open a folder and browse `.md`, `.markdown`, `.html`, and `.htm` files in a sidebar
- Render HTML files directly in WebKit
- Render Markdown as styled HTML preview
- Edit Markdown files with a plain text editor (preview by default)
- Save changes back to disk with unsaved-change protection
- Remembers the last opened folder between launches

## Requirements

- macOS 14 or later
- Xcode 15 or later

## Build and Run

1. Open `MdHtml.xcodeproj` in Xcode
2. Select the `MdHtml` scheme
3. Press Run (⌘R)

Or from the command line:

```bash
xcodebuild -project MdHtml.xcodeproj -scheme MdHtml -configuration Debug build
```

## Usage

1. Launch MdHtml
2. Click **Open Folder** and choose a directory with Markdown/HTML files
3. Select a file in the sidebar to preview it
4. For Markdown files, click **Edit** to modify the source, **Save** to write changes, and **Done** to return to preview

## License

MIT
