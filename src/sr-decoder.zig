
const std = @import("std");
const Decoder = @import("bit-decoder.zig").Decoder;
const Ranker = @import("sr-model.zig").Ranker;

pub const SRDecoder = struct {

    ranker: *Ranker = undefined,
    decoder: *Decoder = undefined,

    pub fn init(ranker: *Ranker, decoder: *Decoder) SRDecoder {
        var sr_decoder = SRDecoder{.ranker = ranker, .decoder = decoder};
        return sr_decoder;
    }

    pub fn give(self: *SRDecoder) !?u8 {

        var i: i32 = 0;
        var ii: i32 = 0;
        var g: i32 = 0;
        var k: usize = 0;
        var sym: u8 = undefined;
        var cap = @clz(self.decoder.bp.cx) - 7;

        if (cap < 18)
            self.decoder.bp.setContext(1);

        var bit: u1 = try self.decoder.give();
        self.decoder.bp.setContext((self.decoder.bp.cx << 1) | bit);

        g = bit;
        while (0 == bit) {
            i += 1;
            bit = try self.decoder.give();
            g = (g << 1) | bit;
            self.decoder.bp.setContext((self.decoder.bp.cx << 1) | bit);
        }
        k = 0;
        while (k < i) : (k += 1) {
            bit = try self.decoder.give();
            g = (g << 1) | bit;
            self.decoder.bp.setContext((self.decoder.bp.cx << 1) | bit);
        }
        if (261 == g) return null;

        if (g < 5) {
            i = g - 1;
            var q = self.ranker.ranked3[self.ranker.ctx];
            sym = switch (i) {
                0 => @intCast(u8, q & 0xFF),
                1 => @intCast(u8, (q >> 8) & 0xFF),
                2 => @intCast(u8, (q >> 16) & 0xFF),
                3 => @intCast(u8, (q >> 24) & 0xFF),
                else => unreachable,
            };
            k = 0;
            while (k < 256) : (k += 1) {
                if (sym == self.ranker.ranked0[k]) {
                    ii = @intCast(i32, k);
                    break;
                }
            }
        } else {
            ii = g - 5;
            sym = self.ranker.ranked0[@intCast(usize, ii)];
            i = -1;
        }

        self.ranker.update(sym, i, ii);
        return sym;
    }
};
