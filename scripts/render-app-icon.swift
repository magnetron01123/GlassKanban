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

    static let paneCorner: CGFloat = 9

    /// Columns overlap and are drawn left to right, each on top of the one
    /// before it. Where two translucent panes cross, the glass darkens — that
    /// doubling is the whole effect, and the reason it reads as glass rather
    /// than as flat bars even at normal icon size.
    static let overlap: CGFloat = 8

    /// Every pane carries a rim all the way round, not just a highlight on its
    /// top edge. An earlier draft lit only the top, and where the panes
    /// overlapped there was no edge to see — the panes fused into one
    /// silhouette and the icon read as a light switch. The rim is what keeps
    /// each pane's outline visible through the stack.
    static let rimWidth: CGFloat = 1.0
    static let contactRimWidth: CGFloat = 1.1

    /// Four columns of equal size — the board's four lanes (Backlog, Als
    /// Nächstes, In Bearbeitung, Erledigt). All identical: they are four of
    /// the same thing, and giving one its own colour or size turned it into a
    /// different kind of object and broke the board reading.
    static let columnCount = 4
    static let columnWidth: CGFloat = 30
    static let columnTop: CGFloat = 36
    static let columnHeight: CGFloat = 88

    /// Centred row: the columns' combined width less the shared overlaps.
    static var rowStart: CGFloat {
        (grid - (columnWidth * CGFloat(columnCount) - overlap * CGFloat(columnCount - 1))) / 2
    }

    /// Left edge of column `i`, counting from 0.
    static func columnX(_ i: Int) -> CGFloat {
        rowStart + CGFloat(i) * (columnWidth - overlap)
    }

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

/// A translucent pane: fill fades top to bottom, edge from `Rim`, plus light
/// caught inside the pane below its top edge.
private struct Pane {
    let fillTop: Double
    let fillBottom: Double
    let rim: Rim
    let innerHighlight: Double
}

private struct Palette {
    let backgroundTop: Color
    let backgroundBottom: Color
    /// What the pane opacities below are laid on. On a white plate the
    /// columns have to darken it, the way the board's lanes are a black wash
    /// on light window glass; on a dark plate they lighten it instead.
    let paneTint: Color
    /// One description for all three columns — they are three of the same
    /// thing. An earlier version gave the middle one its own values and it
    /// read as a different object.
    let column: Pane
    let columnShadow: Double
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
        column: Pane(fillTop: 0.05, fillBottom: 0.15,
                     rim: Rim(highlightTop: 1.0, highlightBottom: 0.6, contact: 0.24),
                     innerHighlight: 0.6),
        columnShadow: 0.20,
        outerShadow: 0.22)

    /// Tuned against the light palette rather than derived from it: the same
    /// opacities look far weaker on a dark ground, so every value here was
    /// raised until the two appearances read as equally glassy side by side.
    static let dark = Palette(
        backgroundTop: Color(hex: 0x434343),
        backgroundBottom: Color(hex: 0x121212),
        paneTint: .white,
        column: Pane(fillTop: 0.16, fillBottom: 0.08,
                     rim: Rim(highlightTop: 0.8, highlightBottom: 0.3, contact: 0.40),
                     innerHighlight: 0.25),
        columnShadow: 0.45,
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
    /// The four columns as flat white shapes. Icon Composer layers are shapes,
    /// not pictures: macOS derives the glass, the specular highlight and the
    /// shadow from them. Handing it a painted version would stack two glass
    /// treatments on each other.
    case columns
    /// The whole painted icon, plate and panes, full-bleed and unclipped. This
    /// is the shipped `.icon`'s single layer: macOS masks it to the icon shape
    /// but — with glass turned off in the manifest — composites it as painted
    /// rather than re-lighting it. Rendered once per appearance, which is the
    /// only reason the icon can switch light/dark at all (a classic
    /// appiconset silently drops its dark entries on macOS).
    case flatFull

    var drawsBackground: Bool { self == .full || self == .backgroundOnly || self == .flatFull }
    var drawsColumns: Bool { self == .full || self == .columns || self == .flatFull }
    /// Only the finished icon carries the outer silhouette and its shadow —
    /// Icon Composer applies its own mask and lighting to bare layers.
    var isMasked: Bool { self == .full }
    var isSilhouette: Bool { self == .columns }
    /// Full-bleed: the plate fills the whole canvas so macOS's own mask rounds
    /// it, instead of the 824-inside-1024 artwork the appiconset needs.
    var isFullBleed: Bool { self == .flatFull }
}

private struct IconArtwork: View {
    let canvas: CGFloat
    let palette: Palette
    let parts: Parts

    /// Side of the rounded square, and the length one grid step maps to.
    /// Full-bleed layers fill the canvas; everything else keeps the 824/1024
    /// margin that holds the hand-drawn outer shadow.
    private var side: CGFloat { parts.isFullBleed ? canvas : canvas * Design.artworkRatio }
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
                // Full-bleed plate is a plain rectangle — macOS rounds the
                // corners with its own mask. The appiconset path keeps drawing
                // the squircle itself.
                Group {
                    if parts.isFullBleed {
                        Rectangle().fill(LinearGradient(
                            colors: [palette.backgroundTop, palette.backgroundBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                    } else {
                        outerShape.fill(LinearGradient(
                            colors: [palette.backgroundTop, palette.backgroundBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                    }
                }
                .frame(width: side, height: side)
                .offset(x: inset, y: inset)
            }

            // Four identical panes — same tint, translucency and edge — drawn
            // left to right so each overlaps the one before it. Depth comes
            // from those overlaps alone: two translucent layers on top of each
            // other darken, which is what glass actually does and what makes
            // the effect visible at normal icon size.
            if parts.drawsColumns {
                ForEach(0..<Design.columnCount, id: \.self) { i in
                    boardColumn(x: Design.columnX(i))
                }
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
    private func boardColumn(x: CGFloat) -> some View {
        column(x, Design.columnTop, Design.columnWidth, Design.columnHeight,
               style: palette.column)
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
                    // Refraction: where light leaves the pane, along the lower
                    // half only. Running it from the top instead put a dark
                    // line under the specular and the pane read as brushed
                    // metal rather than glass.
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(style.rim.contact)],
                            startPoint: .center,
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
            .overlay(alignment: .top) {
                // Light caught inside the pane just under its top edge. This
                // is what separates glass from a flat slab: the brightness
                // sits *within* the shape, not only on its outline.
                if !parts.isSilhouette {
                    shape.fill(LinearGradient(
                        colors: [Color.white.opacity(style.innerHighlight), .clear],
                        startPoint: .top,
                        endPoint: .center))
                }
            }
            .frame(width: width * unit, height: height * unit)
            // A soft shadow to the lower-left, so each pane visibly floats
            // above the one drawn before it (behind it, to its left). This is
            // what makes the overlap read as layered glass rather than one
            // striped surface — without it the panes only meet at their edges.
            // Left off the bare silhouettes: Icon Composer lights those itself.
            .shadow(
                color: .black.opacity(parts.isSilhouette ? 0 : palette.columnShadow),
                radius: 4 * unit,
                x: -1 * unit,
                y: 1 * unit)
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
    "solid" : "display-p3:1.00000,1.00000,1.00000,1.00000"
  },
  "groups" : [
    {
      "layers" : [
        {
          "glass-specializations" : [
            {
              "value" : false
            }
          ],
          "image-name" : "icon-light.png",
          "image-name-specializations" : [
            {
              "appearance" : "dark",
              "value" : "icon-dark.png"
            }
          ],
          "name" : "Icon"
        }
      ],
      "lighting" : "individual",
      "name" : "Icon",
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.0
      },
      "specular" : false,
      "translucency" : {
        "enabled" : false,
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
                              ("2-columns", .columns)] {
            try renderPNG(
                IconArtwork(canvas: 1024, palette: .light, parts: parts),
                pixels: 1024,
                to: layers.appendingPathComponent("layer-\(name).png"))
        }

        // The Icon Composer document itself — this is what ships. A `.icon` is
        // just a folder with a manifest and its layer images, so it is written
        // here rather than clicked together in the app, which keeps it in step
        // with the constants above.
        //
        // Its whole reason for existing over the simpler appiconset is
        // light/dark: a macOS appiconset silently drops its dark entries, an
        // `.icon` does not. The trick is that each layer image is the *fully
        // painted* icon, one per appearance, and the manifest turns glass off —
        // so macOS masks and composites the art as painted instead of
        // re-lighting it, and the appearance switch just swaps which painting
        // it shows.
        let iconBundleAssets = iconBundle.appendingPathComponent("Assets", isDirectory: true)
        try files.createDirectory(at: iconBundleAssets, withIntermediateDirectories: true)
        for (name, palette) in [("icon-light", Palette.light), ("icon-dark", Palette.dark)] {
            try renderPNG(
                IconArtwork(canvas: 1024, palette: palette, parts: .flatFull),
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
