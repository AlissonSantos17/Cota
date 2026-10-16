import AppKit

// Renders the PNGs iconutil expects in an .iconset. Sizes up to 32 px use the
// small art: the dashed baseline turns to noise there.
let args = CommandLine.arguments
guard args.count == 4 else {
  fputs("usage: render-icon.swift <icon.svg> <icon-small.svg> <out.iconset>\n", stderr)
  exit(1)
}
let (full, small, out) = (args[1], args[2], args[3])

func render(_ svg: String, pixels: Int, to path: String) {
  guard let image = NSImage(contentsOfFile: svg),
    let blank = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let rep = blank.retagging(with: .sRGB)
  else {
    fputs("cannot render \(svg)\n", stderr)
    exit(1)
  }
  rep.size = NSSize(width: pixels, height: pixels)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
  NSGraphicsContext.restoreGraphicsState()
  guard let png = rep.representation(using: .png, properties: [:]),
    (try? png.write(to: URL(fileURLWithPath: path))) != nil
  else {
    fputs("cannot write \(path)\n", stderr)
    exit(1)
  }
}

for points in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = points * scale
    let suffix = scale == 1 ? "" : "@2x"
    render(pixels <= 32 ? small : full, pixels: pixels, to: "\(out)/icon_\(points)x\(points)\(suffix).png")
  }
}
