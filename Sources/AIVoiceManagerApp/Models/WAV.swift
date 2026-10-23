import Foundation

/// Where a RIFF/WAVE file keeps its PCM: the `fmt ` chunk's byte rate and sample size, and the `data` chunk's bytes.
/// Gemini sends 24 kHz mono 16-bit, but the header is read rather than assumed. nil = not a WAV we understand.
private struct PCM {
    let byteRate: Int
    let bitsPerSample: Int
    let channels: Int
    let data: Range<Int>

    init?(_ bytes: [UInt8]) {
        guard bytes.count >= 12, bytes[0..<4] == [0x52, 0x49, 0x46, 0x46], bytes[8..<12] == [0x57, 0x41, 0x56, 0x45]
        else { return nil }   // "RIFF" … "WAVE"
        func uint(_ at: Int, _ size: Int) -> Int {
            (0..<size).reduce(0) { $0 | Int(bytes[at + $1]) << (8 * $1) }   // little-endian
        }
        var byteRate = 0, bits = 16, channels = 1, offset = 12
        while offset + 8 <= bytes.count {
            let id = String(bytes: bytes[offset..<offset + 4], encoding: .ascii) ?? "", size = uint(offset + 4, 4)
            let body = offset + 8
            if id == "fmt ", body + 16 <= bytes.count {
                channels = max(1, uint(body + 2, 2))
                byteRate = uint(body + 8, 4)
                bits = uint(body + 14, 2)
            }
            if id == "data" {
                // Streams written before their length is known say 0 / 0xFFFFFFFF: use what's actually there
                let available = bytes.count - body
                let length = size == 0 || size > available ? available : size
                guard byteRate > 0 else { return nil }
                (self.byteRate, bitsPerSample, self.channels, data) = (byteRate, bits, channels, body..<body + length)
                return
            }
            offset = body + size + size % 2   // chunks are word-aligned
        }
        return nil
    }
}

/// Seconds of PCM audio: the `data` chunk's size over the `fmt ` chunk's byte rate.
func wavDuration(_ wav: Data) -> Double? {
    PCM([UInt8](wav)).map { Double($0.data.count) / Double($0.byteRate) }
}

/// The player's 60 bars from the real samples: each bar is its slice's loudest sample, scaled to the loudest slice
/// and drawn 0.2…1 like the seeded bars (so silence still shows a stub). 16-bit PCM only (Gemini's); nil otherwise.
func waveHeights(_ wav: Data, bars: Int = 60) -> [Double]? {
    let bytes = [UInt8](wav)
    guard let pcm = PCM(bytes), pcm.bitsPerSample == 16 else { return nil }
    let frame = 2 * pcm.channels, frames = pcm.data.count / frame
    guard frames >= bars else { return nil }
    let peaks = (0..<bars).map { bar -> Double in
        let range = (frames * bar / bars)..<(frames * (bar + 1) / bars)
        return range.reduce(0) { peak, index in
            let at = pcm.data.lowerBound + index * frame   // first channel is enough for a picture
            let sample = Int16(bitPattern: UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8)
            return max(peak, abs(Double(sample)))
        }
    }
    let loudest = peaks.max() ?? 0
    return peaks.map { 0.2 + 0.8 * (loudest > 0 ? $0 / loudest : 0) }
}
