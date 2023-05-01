
const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Ranker = struct {
    const ORDER = 3;

    // context (3 previous bytes)
    ctx: u24 = 0,
    // per context value ranked lists, 4 bytes long each
    ranked3: []u32 = undefined,
    // common ranked list for misses, 256 bytes long
    ranked0: []u8 = undefined,

    pub fn init(a: Allocator) !Ranker {

        var ranker = Ranker{};

        ranker.ranked0 = try a.alloc(u8, 256);
        var k: usize = 0;
        while (k < 256) : (k += 1) {
            ranker.ranked0[k] = @intCast(u8, k);
        }

        const len = @as(u32, 1) << (8 * ORDER);
        ranker.ranked3 = try a.alloc(u32, len);
        mem.set(u32, ranker.ranked3, 0);
        return ranker;
    }

    pub fn update(self: *Ranker, s: u8, i: i32, ii: i32) void {

        var q = self.ranked3[self.ctx];

        switch (i) {

            -1 => {
                // not in the list
                const b3 = (q & 0x00ff_0000) << 8;  // b3 <- b2
                const b2 = (q & 0x0000_ff00) << 8;  // b2 <- b1
                const b1 = (q & 0x0000_00ff) << 8;  // b1 <- b0
                q = b3 | b2 | b1 | s;
            },

            0 => {
                // leave as is
            },

            1 => {
                const b1 = (q & 0x0000_00ff) << 8;  // b1 <- b0
                const b0 = (q & 0x0000_ff00) >> 8;  // b0 -> b1
                q &= 0xffff_0000;
                q |= b1 | b0;
            },

            2 => {
                const b2 = (q & 0x0000_ff00) << 8;  // b2 <- b1
                const b1 = (q & 0x0000_00ff) << 8;  // b1 <- b0
                const b0 = (q & 0x00ff_0000) >> 16; // b2 -> b0
                q &= 0xff00_0000;
                q |= b2 | b1 | b0;
            },

            3 => {
                const b3 = (q & 0x00ff_0000) << 8;  // b3 <- b2
                const b2 = (q & 0x0000_ff00) << 8;  // b2 <- b1
                const b1 = (q & 0x0000_00ff) << 8;  // b1 <- b0
                const b0 = (q & 0xff00_0000) >> 24; // b3 -> b0
                q = b3 | b2 | b1 | b0;
            },

            else => unreachable,
        }
        self.ranked3[self.ctx] = q;

        // update 'common' list
        // https://hbfs.wordpress.com/2009/03/03/ad-hoc-compression-methods-move-to-front/
        const b: u8 = self.ranked0[@intCast(usize, ii)];
        var k: isize = ii;
        while (k > 0) : (k -= 1) {
            self.ranked0[@intCast(usize, k)] = self.ranked0[@intCast(usize, k) - 1];
        }
        self.ranked0[0] = b;
        self.ctx = (self.ctx << 8) | s;
    }
};
