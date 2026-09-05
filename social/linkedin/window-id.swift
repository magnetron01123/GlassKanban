// Prints the CGWindowID and bounds of the Glass Kanban board window, so that
// `screencapture -l <id>` and `screencapture -R x,y,w,h` can target it.
//   swiftc -O -o /tmp/window-id social/linkedin/window-id.swift && /tmp/window-id
// Output: one line "id=<CGWindowID> x=<x> y=<y> w=<w> h=<h>" (points, top-left origin).
import CoreGraphics
import Foundation

let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    guard w[kCGWindowOwnerName as String] as? String == "Glass Kanban",
          let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
          let id = w[kCGWindowNumber as String] as? Int,
          (bounds["Width"] ?? 0) > 600 // skip tooltips/popovers
    else { continue }
    print("id=\(id) x=\(Int(bounds["X"]!)) y=\(Int(bounds["Y"]!)) w=\(Int(bounds["Width"]!)) h=\(Int(bounds["Height"]!))")
    exit(0)
}
fputs("no Glass Kanban board window on screen\n", stderr)
exit(1)
