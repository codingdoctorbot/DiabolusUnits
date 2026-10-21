// Builds in-game harness textures from proposedart/modular_harnesses.
// Usage (from the addon root):
//   swiftc -O tools/build_harness_art.swift -o /tmp/build_harness_art
//   /tmp/build_harness_art proposedart/modular_harnesses media/harness
// Each piece is cropped to its painted bounds, rails get a cross-faded wrap
// seam, and everything is resampled into power-of-two 32-bit TGAs. The source
// aspect ratios printed at the end belong in core/winglayout.lua (HarnessKits);
// the renderer draws at those ratios, undoing the power-of-two stretch.
import CoreGraphics
import Foundation
import ImageIO

struct Bitmap {
	var w: Int, h: Int, px: [UInt8] // premultiplied RGBA, row 0 = top
}

func load(_ path: String) -> Bitmap? {
	guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
		let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
	var bm = Bitmap(w: img.width, h: img.height, px: [UInt8](repeating: 0, count: img.width * img.height * 4))
	let ctx = CGContext(data: &bm.px, width: bm.w, height: bm.h, bitsPerComponent: 8, bytesPerRow: bm.w * 4,
		space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	ctx.draw(img, in: CGRect(x: 0, y: 0, width: bm.w, height: bm.h))
	return bm
}

func crop(_ b: Bitmap) -> Bitmap {
	var minX = b.w, minY = b.h, maxX = -1, maxY = -1
	for y in 0..<b.h { for x in 0..<b.w where b.px[(y * b.w + x) * 4 + 3] > 8 {
		minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
	} }
	let w = maxX - minX + 1, h = maxY - minY + 1
	var out = Bitmap(w: w, h: h, px: [UInt8](repeating: 0, count: w * h * 4))
	for y in 0..<h { for x in 0..<w { for c in 0..<4 {
		out.px[(y * w + x) * 4 + c] = b.px[((y + minY) * b.w + x + minX) * 4 + c]
	} } }
	return out
}

// Blend the last k columns into the first k so the strip wraps without a seam.
func seamless(_ b: Bitmap) -> Bitmap {
	let k = b.w / 4, w = b.w - k
	var out = Bitmap(w: w, h: b.h, px: [UInt8](repeating: 0, count: w * b.h * 4))
	for y in 0..<b.h { for x in 0..<w {
		for c in 0..<4 {
			let a = Double(b.px[(y * b.w + x) * 4 + c])
			guard x < k else { out.px[(y * w + x) * 4 + c] = UInt8(a); continue }
			let t = Double(x) / Double(k), z = Double(b.px[(y * b.w + x + w) * 4 + c])
			out.px[(y * w + x) * 4 + c] = UInt8(min(255, (a * t + z * (1 - t)).rounded()))
		}
	} }
	return out
}

func image(_ b: Bitmap) -> CGImage {
	var px = b.px
	let ctx = CGContext(data: &px, width: b.w, height: b.h, bitsPerComponent: 8, bytesPerRow: b.w * 4,
		space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	return ctx.makeImage()!
}

func pot(_ n: Double) -> Int { max(16, min(256, 1 << Int(log2(max(n, 1)).rounded()))) }

func resample(_ b: Bitmap, _ w: Int, _ h: Int) -> Bitmap {
	var out = Bitmap(w: w, h: h, px: [UInt8](repeating: 0, count: w * h * 4))
	let ctx = CGContext(data: &out.px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
		space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	ctx.interpolationQuality = .high
	ctx.draw(image(b), in: CGRect(x: 0, y: 0, width: w, height: h))
	return out
}

// Uncompressed 32-bit, bottom-left origin: the same header as media/*.tga.
func writeTGA(_ b: Bitmap, _ path: String) {
	var data = Data([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		UInt8(b.w & 255), UInt8(b.w >> 8), UInt8(b.h & 255), UInt8(b.h >> 8), 32, 8])
	for y in stride(from: b.h - 1, through: 0, by: -1) { for x in 0..<b.w {
		let i = (y * b.w + x) * 4, a = Int(b.px[i + 3])
		func un(_ v: UInt8) -> UInt8 { a == 0 ? 0 : UInt8(min(255, (Int(v) * 255 + a / 2) / a)) }
		data.append(contentsOf: [un(b.px[i + 2]), un(b.px[i + 1]), un(b.px[i]), UInt8(a)])
	} }
	try! data.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
let source = args.count > 1 ? args[1] : "proposedart/modular_harnesses"
let target = args.count > 2 ? args[2] : "media/harness"
let fm = FileManager.default
let kits = try! fm.contentsOfDirectory(atPath: source).filter { !$0.hasPrefix(".") }.sorted()
// Display heights in source-independent texels: caps carry the detail.
let pieces: [(String, Int, Bool)] = [("cap_left", 128, false), ("cap_right", 128, false),
	("rail_top", 32, true), ("rail_bottom", 32, true), ("crest", 64, false)]
for kit in kits {
	let id = String(kit.drop { $0.isNumber || $0 == "_" })
	try? fm.createDirectory(atPath: "\(target)/\(id)", withIntermediateDirectories: true)
	var fields: [String] = []
	for (name, height, rail) in pieces {
		guard var bm = load("\(source)/\(kit)/\(name).png") else { continue }
		bm = crop(bm)
		if rail { bm = seamless(bm) }
		let aspect = Double(bm.w) / Double(bm.h)
		writeTGA(resample(bm, pot(Double(height) * aspect), height), "\(target)/\(id)/\(name).tga")
		let key = name.replacingOccurrences(of: "_l", with: "L").replacingOccurrences(of: "_r", with: "R")
			.replacingOccurrences(of: "_t", with: "T").replacingOccurrences(of: "_b", with: "B")
		fields.append(String(format: "%@ = %.3f", key, aspect))
	}
	print("\(id) = { \(fields.joined(separator: ", ")) },")
}
