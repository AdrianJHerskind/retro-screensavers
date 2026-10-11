import AppKit

if let path = argumentValue("--snapshot") {
    exit(Snapshot.writeSnapshot(to: path))
}
if let directory = argumentValue("--thumbnails") {
    exit(Snapshot.writeThumbnails(to: directory))
}

let app = NSApplication.shared
let delegate = HarnessAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
