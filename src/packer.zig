
const std = @import("std");
const os = std.os;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;

const BitPredictor = @import("bit-predictor.zig").BitPredictor;
const Encoder = @import("bit-encoder.zig").Encoder;
const Decoder = @import("bit-decoder.zig").Decoder;
const Reader = @import("buff-reader.zig").Reader;
const Writer = @import("buff-writer.zig").Writer;
const Ranker = @import("sr-model.zig").Ranker;
const SREncoder = @import("sr-encoder.zig").SREncoder;
const SRDecoder = @import("sr-decoder.zig").SRDecoder;

pub fn compress(rf: *fs.File, size: u64, wf: *fs.File, a: Allocator) !void {

    var k: usize = 0;
    var reader = try Reader.init(rf, 4096, a);
    var writer = try Writer.init(wf, 4096, a);
    var bp = try BitPredictor.init(a);
    var encoder = Encoder.init(&bp, wf, &writer);
    var ranker = try Ranker.init(a);
    var sr_encoder = SREncoder.init(&ranker, &encoder);

    // store file header
    var buf: [4]u8 = .{'s','r','z', 0};
    try writer.take(buf[0]);
    try writer.take(buf[1]);
    try writer.take(buf[2]);
    try writer.take(buf[3]);

    while (k < size) : (k += 1) {
        var byte = try reader.give() orelse unreachable;
        try sr_encoder.take(byte);
    }
    try sr_encoder.eof();
}

const DecompressError = error {
    IsNotSRZFile,
};

pub fn decompress(rf: *fs.File, wf: *fs.File, a: Allocator) !void {

    var reader = try Reader.init(rf, 4096, a);
    var writer = try Writer.init(wf, 4096, a);
    var byte: u8 = 0;

    // fetch file header
    byte = try reader.give() orelse unreachable;
    if (byte != 's') return DecompressError.IsNotSRZFile;
    byte = try reader.give() orelse unreachable;
    if (byte != 'r') return DecompressError.IsNotSRZFile;
    byte = try reader.give() orelse unreachable;
    if (byte != 'z') return DecompressError.IsNotSRZFile;
    byte  = try reader.give() orelse unreachable;
    if (byte != 0) return DecompressError.IsNotSRZFile;

    var bp = try BitPredictor.init(a);
    var decoder = try Decoder.init(&bp, rf, &reader);
    var ranker = try Ranker.init(a);
    var sr_decoder = SRDecoder.init(&ranker, &decoder);

    while (true) {
        byte = try sr_decoder.give() orelse break;
        _ = try writer.take(byte);
    }
    try writer.flush();
}
