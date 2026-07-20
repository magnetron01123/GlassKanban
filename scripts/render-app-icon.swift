#!/usr/bin/env swift

// Renders the Glass Kanban app icon (see design/app-icon-concept.md).
//
// The icon is generated rather than hand-drawn so that geometry and colours
// live in one readable place instead of inside a binary. Re-run after any
// change to the constants below.
//
//   swift scripts/render-app-icon.swift <output-directory>
//
// Writes:
//   <out>/AppIcon.appiconset/     complete asset catalog set, ready to copy
//   <out>/layers/                 the three layers for Icon Composer
//   <out>/preview/                light and dark renders for eyeballing
//
// Shapes are drawn with SwiftUI's `.continuous` rounded rectangle — the same
// squircle family the board itself uses (see Board.columnShape). A circular
// corner would read as "nearly native" the way `DesignSystem.swift` warns.

import SwiftUI
import AppKit

// MARK: - Design tokens

/// Everything is authored on a 160×160 grid and scaled at render time, so the
/// numbers below match the concept document one to one.
private enum Design {
    static let grid: CGFloat = 160

    /// macOS draws app icons as an 824×824 rounded square inside a 1024
    /// canvas; the remaining margin is where the icon's shadow lives.
    static let artworkRatio: CGFloat = 824.0 / 1024.0
    static let artworkCornerRatio: CGFloat = 185.4 / 824.0

    static let paneCorner: CGFloat = 11

    /// Every pane carries a rim all the way round, not just a highlight on its
    /// top edge. An earlier draft lit only the top, and where the panes
    /// overlapped there was no edge to see — the three fused into one
    /// silhouette and the icon read as a light switch. The rim plus the front
    /// pane's shadow is what makes overlap read as layered glass.
    static let rimWidth: CGFloat = 1.0
    static let contactRimWidth: CGFloat = 1.1

    /// The two storage panes (Backlog, Erledigt): shorter and fainter, sitting
    /// behind. Both say the same thing — stored, not being worked on — which
    /// is why three panes stand in for the board's four columns.
    static let backWidth: CGFloat = 48
    static let backTop: CGFloat = 43
    static let backHeight: CGFloat = 74
    static let backLeftX: CGFloat = 14
    static let backRightX: CGFloat = 98

    /// The work in progress: wider, taller, brighter, in front, casting a
    /// shadow on the other two. Kanban's whole discipline is the WIP limit —
    /// "stop starting, start finishing" — so the eye belongs here, not on the
    /// archive. The width ratio mirrors the 440-to-320pt split the real board
    /// uses on wide displays.
    static let frontWidth: CGFloat = 58
    static let frontX: CGFloat = 51
    static let frontTop: CGFloat = 34
    static let frontHeight: CGFloat = 92

    /// Above this pixel size the icon carries its own outer drop shadow. Below
    /// it the shadow only eats pixels the silhouette needs.
    static let detailThreshold: CGFloat = 32
}

/// A pane's two-tone edge. Glass shows a bright specular line where light
/// enters at the top and a dark refraction line where it leaves at the bottom.
/// Only the bright half was drawn at first, which works in dark mode — white
/// on a dark pane is high contrast — but vanishes in light mode, where white
/// sits on an already-light pane. The dark half is what gives the light
/// variant an edge at all, and it is why both appearances now read as glass.
private struct Rim {
    let highlightTop: Double
    let highlightBottom: Double
    let contact: Double
}

/// A translucent pane: fill fades top to bottom, edge from `Rim`.
private struct Pane {
    let fillTop: Double
    let fillBottom: Double
    let rim: Rim
}

private struct Palette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let back: Pane
    let front: Pane
    let frontShadow: Double
    let outerShadow: Double

    /// Neutral grey, no hue at all — the GUI leads here. The window's own
    /// material (`.hudWindow`, see HUDGlassMaterial.swift) measures exactly
    /// R=G=B at every backdrop, cards are plain white, and lanes are a black
    /// wash; nothing in the app carries a tint. An earlier draft used a
    /// grey-blue and stood out against its own window.
    ///
    /// The gradient is wider than a first glance suggests it needs to be:
    /// translucent panes only read as translucent if there is something behind
    /// them to see through to. Its mid value lands on the glass tone the
    /// window shows over a neutral desktop.
    static let light = Palette(
        backgroundTop: Color(hex: 0xDADADA),
        backgroundBottom: Color(hex: 0x969696),
        back: Pane(fillTop: 0.26, fillBottom: 0.06,
                   rim: Rim(highlightTop: 1.0, highlightBottom: 0.16, contact: 0.26)),
        front: Pane(fillTop: 0.58, fillBottom: 0.28,
                    rim: Rim(highlightTop: 1.0, highlightBottom: 0.24, contact: 0.34)),
        frontShadow: 0.42,
        outerShadow: 0.25)

    /// Tuned against the light palette rather than derived from it: the same
    /// opacities look far weaker on a dark ground, so every value here was
    /// raised until the two appearances read as equally glassy side by side.
    static let dark = Palette(
        backgroundTop: Color(hex: 0x434343),
        backgroundBottom: Color(hex: 0x121212),
        back: Pane(fillTop: 0.12, fillBottom: 0.05,
                   rim: Rim(highlightTop: 0.65, highlightBottom: 0.18, contact: 0.35)),
        front: Pane(fillTop: 0.34, fillBottom: 0.16,
                    rim: Rim(highlightTop: 1.0, highlightBottom: 0.30, contact: 0.45)),
        frontShadow: 0.70,
        outerShadow: 0.30)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Artwork

/// Which parts to draw. The asset catalog wants the whole icon; Icon Composer
/// wants each layer on its own so macOS can light them separately.
private enum Parts {
    case full
    case backgroundOnly
    case backPanes
    case frontPane
    /// Bare silhouettes for the `.icon` bundle. Icon Composer layers are
    /// shapes, not pictures: macOS derives the glass, the specular highlight
    /// and the shadow from them, and does it per appearance. Handing it the
    /// painted version would mean two glass treatments stacked on each other.
    case silhouetteBackPanes
    case silhouetteFrontPane

    var drawsBackground: Bool { self == .full || self == .backgroundOnly }
    var drawsBack: Bool { self == .full || self == .backPanes || self == .silhouetteBackPanes }
    var drawsFront: Bool { self == .full || self == .frontPane || self == .silhouetteFrontPane }
    /// Only the finished icon carries the outer silhouette and its shadow —
    /// Icon Composer applies its own mask and lighting to bare layers.
    var isMasked: Bool { self == .full }
    var isSilhouette: Bool { self == .silhouetteBackPanes || self == .silhouetteFrontPane }
}

private struct IconArtwork: View {
    let canvas: CGFloat
    let palette: Palette
    let parts: Parts

    /// Side of the rounded square, and the length one grid step maps to.
    private var side: CGFloat { canvas * Design.artworkRatio }
    private var unit: CGFloat { side / Design.grid }
    private var inset: CGFloat { (canvas - side) / 2 }
    private var detailed: Bool { canvas > Design.detailThreshold }

    private var outerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: side * Design.artworkCornerRatio, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            if parts.drawsBackground {
                outerShape
                    .fill(LinearGradient(
                        colors: [palette.backgroundTop, palette.backgroundBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: side, height: side)
                    .offset(x: inset, y: inset)
            }

            if parts.drawsBack {
                backPane(x: Design.backLeftX)
                backPane(x: Design.backRightX)
            }

            if parts.drawsFront {
                pane(
                    Design.frontX, Design.frontTop, Design.frontWidth, Design.frontHeight,
                    style: palette.front,
                    shadow: palette.frontShadow)
            }
        }
        .frame(width: canvas, height: canvas)
        // Clipping only matters for the finished icon; layers stay full-bleed
        // so Icon Composer can mask them itself.
        .clipShape(parts.isMasked
            ? AnyShape(outerShape.offset(x: inset, y: inset))
            : AnyShape(Rectangle()))
        // The icon's own drop shadow, which is what the 1024/824 margin exists
        // for in the first place.
        .shadow(
            color: .black.opacity(parts.isMasked && detailed ? palette.outerShadow : 0),
            radius: side * 0.018,
            y: side * 0.012)
    }

    private func backPane(x: CGFloat) -> some View {
        pane(x, Design.backTop, Design.backWidth, Design.backHeight,
             style: palette.back, shadow: nil)
    }

    /// One glass pane: a fill that fades downward, a dark contact edge, a
    /// bright specular edge, and — for the front pane — a shadow onto the two
    /// behind it. Drawn in that order because the specular has to sit on top
    /// of the contact line, not under it.
    private func pane(
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        style: Pane,
        shadow: Double?
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Design.paneCorner * unit, style: .continuous)
        return shape
            .fill(parts.isSilhouette
                ? AnyShapeStyle(Color.white)
                : AnyShapeStyle(LinearGradient(
                    colors: [Color.white.opacity(style.fillTop),
                             Color.white.opacity(style.fillBottom)],
                    startPoint: .top,
                    endPoint: .bottom)))
            .overlay {
                if !parts.isSilhouette {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(style.rim.contact)],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: max(0.75, Design.contactRimWidth * unit))
                }
            }
            .overlay {
                if !parts.isSilhouette {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(style.rim.highlightTop),
                                     Color.white.opacity(style.rim.highlightBottom)],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: max(0.75, Design.rimWidth * unit))
                }
            }
            .frame(width: width * unit, height: height * unit)
            .shadow(
                color: .black.opacity(parts.isSilhouette ? 0 : (shadow ?? 0)),
                radius: 5 * unit,
                y: 2 * unit)
            .offset(x: inset + x * unit, y: inset + y * unit)
    }
}

// MARK: - Rendering

@MainActor
private func renderPNG(_ view: some View, pixels: CGFloat, to url: URL) throws {
    let renderer = ImageRenderer(content: view.frame(width: pixels, height: pixels))
    renderer.scale = 1
    guard let image = renderer.cgImage else {
        throw Failure("ImageRenderer produced no image for \(url.lastPathComponent)")
    }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw Failure("PNG encoding failed for \(url.lastPathComponent)")
    }
    try data.write(to: url)
}

private struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// One asset-catalog slot. Several slots share a pixel size (16@2x and 32@1x
/// are both 32 pixels) but need their own file, so the image is rendered once
/// per distinct size and written under each name that wants it.
private struct Slot {
    let points: Int
    let scale: Int
    var pixels: Int { points * scale }
    var filename: String { "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png" }
    var json: String {
        """
            {
              "filename" : "\(filename)",
              "idiom" : "mac",
              "scale" : "\(scale)x",
              "size" : "\(points)x\(points)"
            }
        """
    }
}

private let slots: [Slot] = [16, 32, 128, 256, 512].flatMap { points in
    [Slot(points: points, scale: 1), Slot(points: points, scale: 2)]
}

/// The `.icon` manifest — an Icon Composer document, written here rather than
/// clicked together in the app. The format is a folder holding this manifest
/// plus its layer images, so it stays in step with the constants above instead
/// of drifting from them.
///
/// Two groups, because Icon Composer attaches shadows per group, not per
/// layer, and the front pane has to sit deeper than the two behind it — that
/// depth order is the whole composition.
///
/// The plate carries the same gradient as the painted variant. The dark and
/// tinted appearances are deliberately left to macOS: a compiled catalog holds
/// separate layer stacks for `NSAppearanceNameAqua`,
/// `NSAppearanceNameDarkAqua` and `ISAppearanceTintable` even when the manifest
/// says nothing about them. Letting the system derive them is the point of the
/// format — every icon then goes through the same tuned pipeline — and it is
/// exactly what a hand-painted asset catalog cannot do.
///
/// `display-p3` values equal the sRGB ones here because every colour is
/// neutral: the two spaces share a transfer function and a neutral axis, so
/// R=G=B needs no conversion.
private let iconManifest = """
{
  "fill" : {
    "linear-gradient" : [
      "display-p3:0.85490,0.85490,0.85490,1.00000",
      "display-p3:0.58824,0.58824,0.58824,1.00000"
    ]
  },
  "groups" : [
    {
      "layers" : [
        {
          "image-name" : "storage-panes.png",
          "name" : "Storage lanes"
        }
      ],
      "lighting" : "individual",
      "name" : "Storage",
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.35
      },
      "specular" : true,
      "translucency" : {
        "enabled" : true,
        "value" : 0.8
      }
    },
    {
      "layers" : [
        {
          "image-name" : "focus-pane.png",
          "name" : "Work in progress"
        }
      ],
      "lighting" : "individual",
      "name" : "Focus",
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.5
      },
      "specular" : true,
      "translucency" : {
        "enabled" : true,
        "value" : 0.8
      }
    }
  ],
  "supported-platforms" : {
    "squares" : [
      "macOS"
    ]
  }
}

"""

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(
        "usage: swift scripts/render-app-icon.swift <output-directory>\n".data(using: .utf8)!)
    exit(2)
}

let root = URL(fileURLWithPath: arguments[1], isDirectory: true)
let appIconSet = root.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let iconBundle = root.appendingPathComponent("AppIcon.icon", isDirectory: true)
let layers = root.appendingPathComponent("layers", isDirectory: true)
let preview = root.appendingPathComponent("preview", isDirectory: true)

do {
    let files = FileManager.default
    for directory in [appIconSet, iconBundle, layers, preview] {
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    try MainActor.assumeIsolated {
        // Asset catalog. Rendered once per distinct pixel size, then written
        // under every slot name that asks for it.
        var rendered: [Int: Data] = [:]
        for pixels in Set(slots.map(\.pixels)).sorted() {
            let scratch = appIconSet.appendingPathComponent("scratch.png")
            try renderPNG(
                IconArtwork(canvas: CGFloat(pixels), palette: .light, parts: .full),
                pixels: CGFloat(pixels),
                to: scratch)
            rendered[pixels] = try Data(contentsOf: scratch)
            try files.removeItem(at: scratch)
        }
        for slot in slots {
            try rendered[slot.pixels]?
                .write(to: appIconSet.appendingPathComponent(slot.filename))
        }

        let contents = """
        {
          "images" : [
        \(slots.map(\.json).joined(separator: ",\n"))
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }

        """
        try contents.write(
            to: appIconSet.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8)

        // Painted layers, back to front — reference material, and a starting
        // point if the .icon bundle is ever rebuilt by hand in Icon Composer.
        for (name, parts) in [("1-background", Parts.backgroundOnly),
                              ("2-storage-panes", .backPanes),
                              ("3-focus-pane", .frontPane)] {
            try renderPNG(
                IconArtwork(canvas: 1024, palette: .light, parts: parts),
                pixels: 1024,
                to: layers.appendingPathComponent("layer-\(name).png"))
        }

        // The Icon Composer document itself. A `.icon` is just a folder with a
        // manifest and its layer images, so it can be written here rather than
        // clicked together in the app — which keeps it in step with the
        // constants above instead of drifting from them.
        let iconBundleAssets = iconBundle.appendingPathComponent("Assets", isDirectory: true)
        try files.createDirectory(at: iconBundleAssets, withIntermediateDirectories: true)
        for (name, parts) in [("storage-panes", Parts.silhouetteBackPanes),
                              ("focus-pane", .silhouetteFrontPane)] {
            try renderPNG(
                IconArtwork(canvas: 1024, palette: .light, parts: parts),
                pixels: 1024,
                to: iconBundleAssets.appendingPathComponent("\(name).png"))
        }
        try iconManifest.write(
            to: iconBundle.appendingPathComponent("icon.json"),
            atomically: true,
            encoding: .utf8)

        // Previews, including the sizes where the design is actually at risk.
        for (name, palette) in [("light", Palette.light), ("dark", Palette.dark)] {
            for pixels in [16, 32, 128, 1024] {
                try renderPNG(
                    IconArtwork(canvas: CGFloat(pixels), palette: palette, parts: .full),
                    pixels: CGFloat(pixels),
                    to: preview.appendingPathComponent("\(name)-\(pixels).png"))
            }
        }
    }

    print("Wrote \(slots.count) icon files, AppIcon.icon, 3 layers and 8 previews to \(root.path)")
} catch {
    FileHandle.standardError.write("failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
