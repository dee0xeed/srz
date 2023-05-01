
const std = @import("std");
const Encoder = @import("bit-encoder.zig").Encoder;
const Ranker = @import("sr-model.zig").Ranker;

pub const SREncoder = struct {

    ranker: *Ranker = undefined,
    encoder: *Encoder = undefined,

    pub fn init(ranker: *Ranker, encoder: *Encoder) SREncoder {
        var sr_encoder = SREncoder{.ranker = ranker, .encoder = encoder};
        return sr_encoder;
    }

    inline fn outputEliasGammaCode(self: *SREncoder, rank: u32) !void {
        var b: isize  = 2 * (32 - @clz(rank)) - 2;
        const cap: u8 = @clz(self.encoder.bp.cx) - 7;
        if (cap < 18)
            self.encoder.bp.setContext(1);
        while (b >= 0) : (b -= 1) {
            var bit: u1 = @intCast(u1, (rank >> @intCast(u5, b)) & 1);
            try self.encoder.take(bit);
            self.encoder.bp.setContext((self.encoder.bp.cx << 1) | bit);
        }
    }

    pub fn take(self: *SREncoder, sym: u8) !void {

        var k: i32 = 0;
        var i: i32 = -1;
        var ii: i32 = 0;
        var q = self.ranker.ranked3[self.ranker.ctx];

        while (k < 4) : (k += 1) {
            if (sym == (q >> @intCast(u5, (k * 8))) & 0xff) {
                i = k;
                break;
            }
        }

        k = 0;
        while (k < 256) : (k += 1) {
            if (sym == self.ranker.ranked0[@intCast(usize, k)]) {
                ii = k;
                break;
            }
        }

        var r: i32 = if (i >= 0) i + 1 else ii + 5;
        try outputEliasGammaCode(self, @intCast(u24, r));
        self.ranker.update(sym, i, ii);
    }

    pub fn eof(self: *SREncoder) !void {
        try outputEliasGammaCode(self, 261);
        try self.encoder.foldup();
        //const ppp = 100 * self.c1 / (self.c1 + self.c2);
        //std.debug.print("{} matches {}%, {} misses\n", .{self.c1, ppp, self.c2});
    }
};
