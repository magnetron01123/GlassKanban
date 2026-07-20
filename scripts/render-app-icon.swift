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

    static let paneCorner: CGFloat = 10

    /// Slight overlap, not a stack. What separates the columns is the middle
    /// one's shadow falling on the two behind it — which is why it sits in its
    /// own group (Icon Composer attaches shadows per group, never per layer).
    static let overlap: CGFloat = 7

    /// Every pane carries a rim all the way round, not just a highlight on its
    /// top edge. An earlier draft lit only the top, and where the panes
    /// overlapped there was no edge to see — the three fused into one
    /// silhouette and the icon read as a light switch. The rim plus the front
    /// pane's shadow is what makes overlap read as layered glass.
    static let rimWidth: CGFloat = 1.0
    static let contactRimWidth: CGFloat = 1.1

    /// Three columns of equal size — one board, three of the same thing. The
    /// middle one is emphasised by sitting in front, not by being larger or a
    /// different colour: an earlier version made it taller and tinted the
    /// outer two darker, which turned them into a different kind of object and
    /// the board reading was gone.
    static let columnWidth: CGFloat = 38
    static let columnTop: CGFloat = 41
    static let columnHeight: CGFloat = 78

    /// Centred row: three columns less the two overlaps.
    static var rowStart: CGFloat {
        (grid - (columnWidth * 3 - overlap * 2)) / 2
    }
    static var centerX: CGFloat { rowStart + columnWidth - overlap }
    static var rightX: CGFloat { centerX + columnWidth - overlap }

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
    /// What the pane opacities below are laid on. On a white plate the
    /// columns have to darken it, the way the board's lanes are a black wash
    /// on light window glass; on a dark plate they lighten it instead.
    let paneTint: Color
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
    /// White, like Reminders — its plate measures #FEFEFF at the top and
    /// #EFEFEF at the bottom. A grey icon sat oddly among the system apps in
    /// the Dock; white puts it in the same family, and it happens to mirror
    /// the board better: there the window is light and the lanes darken it.
    static let light = Palette(
        backgroundTop: Color(hex: 0xFEFEFF),
        backgroundBottom: Color(hex: 0xEBEBED),
        paneTint: .black,
        back: Pane(fillTop: 0.16, fillBottom: 0.26,
                   rim: Rim(highlightTop: 0.85, highlightBottom: 0.0, contact: 0.16)),
        front: Pane(fillTop: 0.11, fillBottom: 0.21,
                    rim: Rim(highlightTop: 1.0, highlightBottom: 0.0, contact: 0.22)),
        frontShadow: 0.30,
        outerShadow: 0.22)

    /// Tuned against the light palette rather than derived from it: the same
    /// opacities look far weaker on a dark ground, so every value here was
    /// raised until the two appearances read as equally glassy side by side.
    static let dark = Palette(
        backgroundTop: Color(hex: 0x434343),
        backgroundBottom: Color(hex: 0x121212),
        paneTint: .white,
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
    /// The two outer columns, and the middle one, as flat white shapes. Icon
    /// Composer layers are shapes, not pictures: macOS derives the glass, the
    /// specular highlight and the shadow from them. Handing it a painted
    /// version would stack two glass treatments on each other.
    ///
    /// Split in two because they overlap: the middle column needs its own
    /// shadow to read as being in front, and shadows are per group.
    case outerColumns
    case centerColumn

    var drawsBackground: Bool { self == .full || self == .backgroundOnly }
    var drawsOuter: Bool { self == .full || self == .outerColumns }
    var drawsCenter: Bool { self == .full || self == .centerColumn }
    /// Only the finished icon carries the outer silhouette and its shadow —
    /// Icon Composer applies its own mask and lighting to bare layers.
    var isMasked: Bool { self == .full }
    var isSilhouette: Bool { self == .outerColumns || self == .centerColumn }
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

            if parts.drawsOuter {
                boardColumn(x: Design.rowStart, style: palette.back)
                boardColumn(x: Design.rightX, style: palette.back)
            }

            if parts.drawsCenter {
                boardColumn(x: Design.centerX, style: palette.front)
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

    /// One column. In the shipped `.icon` this is a flat white shape and macOS
    /// lights it; the painted fill and edges below only feed the fallback
    /// asset catalog and the previews.
    private func boardColumn(x: CGFloat, style: Pane) -> some View {
        column(x, Design.columnTop, Design.columnWidth, Design.columnHeight, style: style)
    }

    private func column(
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        style: Pane
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Design.paneCorner * unit, style: .continuous)
        return shape
            .fill(parts.isSilhouette
                ? AnyShapeStyle(Color.white)
                : AnyShapeStyle(LinearGradient(
                    colors: [palette.paneTint.opacity(style.fillTop),
                             palette.paneTint.opacity(style.fillBottom)],
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
/// A solid plate carrying three glass columns of equal size, the middle one in
/// front. The plate colour is the app's own: `#DCDEE0` is the window glass
/// measured in the running board, and the dark value is the same surface in
/// Dark Mode. Solid rather than a gradient, so the plate reads as one surface.
///
/// Two groups because the columns overlap: the middle one carries a deeper
/// shadow so it reads as being in front, and Icon Composer attaches shadows
/// per group, never per layer. That shadow is the only thing separating the
/// three — an earlier attempt separated them by making the outer two darker
/// and taller-vs-shorter instead, which turned them into a different kind of
/// object and the board reading was gone.
///
/// The plate is a good deal deeper than the app's own surfaces, and that is
/// on purpose. An earlier version matched the window's measured tone
/// (`#DCDEE0`) and vanished on a light Dock: the app's surfaces sit on the
/// user's wallpaper and borrow contrast from it, while an icon has nothing
/// behind it and has to carry its own. Checked against both a light and a
/// dark backdrop at full size and at 32pt.
///
/// Dark is specified rather than left to the system. The fill is a literal
/// colour, so without an override the plate stays light in Dark Mode and the
/// icon reads far too bright there.
///
/// `display-p3` values equal the sRGB ones here because every colour is
/// neutral: the two spaces share a transfer function and a neutral axis, so
/// R=G=B needs no conversion.
private let iconManifest = """
{
  "fill" : {
    "solid" : "display-p3:0.55294,0.56078,0.56863,1.00000"
  },
  "fill-specializations" : [
    {
      "appearance" : "dark",
      "value" : {
        "solid" : "display-p3:0.24706,0.25098,0.25490,1.00000"
      }
    }
  ],
  "groups" : [
    {
      "layers" : [
        {
          "image-name" : "columns-outer.png",
          "name" : "Backlog and Erledigt"
        }
      ],
      "lighting" : "individual",
      "name" : "Outer columns",
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.3
      },
      "specular" : true,
      "translucency" : {
        "enabled" : true,
        "value" : 0.5
      }
    },
    {
      "layers" : [
        {
          "image-name" : "columns-center.png",
          "name" : "In Bearbeitung"
        }
      ],
      "lighting" : "individual",
      "name" : "Center column",
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.55
      },
      "specular" : true,
      "translucency" : {
        "enabled" : true,
        "value" : 0.5
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

        // The two layers on their own — reference material, and a starting
        // point if the .icon bundle is ever rebuilt by hand in Icon Composer.
        for (name, parts) in [("1-plate", Parts.backgroundOnly),
                              ("2-columns-outer", .outerColumns),
                              ("3-columns-center", .centerColumn)] {
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
        for (name, parts) in [("columns-outer", Parts.outerColumns),
                              ("columns-center", .centerColumn)] {
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
