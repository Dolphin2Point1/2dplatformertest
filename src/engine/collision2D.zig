const std = @import("std");
const math = @import("math.zig");

pub const Box = struct {
    lessPos: math.f32x2,
    greaterPos: math.f32x2
};

/// Checks if two intervals overlap, including the endpoints.
pub inline fn intervals_overlap_exclusive(p11: f32, p12: f32, p21: f32, p22: f32) bool {
    return @min(p11, p12) < @max(p21, p22) and @min(p21, p22) < @max(p11, p12);
}

/// Checks if a swept box defined by the first two parameters intersects the stationary box in the second parameter.
pub fn swept_box_collision(box1: Box, sweep: math.f32x2, box2: Box) bool {
    const util = struct {
        fn maxEach(_: usize, x: f32) f32 {
            return @max(x, 0);
        }

        fn minEach(_: usize, x: f32) f32 {
            return @min(x, 0);
        }
    };
    const sweptBB = Box { .lessPos = math.add(box1.lessPos, math.doEach(sweep, util.minEach)), .greaterPos = math.add(box1.greaterPos, math.doEach(sweep, util.maxEach)) };

    // x-axis
    if(!intervals_overlap_exclusive(sweptBB.lessPos[0], sweptBB.greaterPos[0], box2.lessPos[0], box2.greaterPos[0])) {
        return false;
    }

    // y-axis
    if(!intervals_overlap_exclusive(sweptBB.lessPos[1], sweptBB.greaterPos[1], box2.lessPos[1], box2.greaterPos[1])) {
        return false;
    }
    
    if(sweep[0] == 0 and sweep[1] == 0) {
        return false;
    }

    const pos_slope = sweep[0] == 0 or ((sweep[1]/sweep[0]) > 0);
    const n = math.rotate2D90DegCCW(sweep);
    const pos1 = if(pos_slope) .{box1.greaterPos[0], box1.lessPos[1]} else box1.lessPos;
    const pos2 = if(pos_slope) .{box1.lessPos[0], box1.greaterPos[1]} else box1.greaterPos;
    const b2p1 = if(pos_slope) .{box2.greaterPos[0], box2.lessPos[1]} else box2.lessPos;
    const b2p2 = if(pos_slope) .{box2.lessPos[0], box2.greaterPos[1]} else box2.greaterPos;

    if(!intervals_overlap_exclusive(math.dot(pos1, n), math.dot(pos2, n), math.dot(b2p1, n), math.dot(b2p2, n))) {
        return false;
    }

    return true;
}

pub fn swept_box_collision_normal(box1: Box, sweep: math.f32x2, box2: Box) math.f32x2 {
    const xoverlap = intervals_overlap_exclusive(box1.lessPos[0], box1.greaterPos[0], box2.lessPos[0], box2.greaterPos[0]);
    const yoverlap = intervals_overlap_exclusive(box1.lessPos[1], box1.greaterPos[1], box2.lessPos[1], box2.greaterPos[1]);
    if(xoverlap and yoverlap) return .{0,0};
    
    const util = struct {
        fn sign(_: usize, x: f32) f32 {
            return std.math.sign(x) - @intFromBool(x == 0);
        }

        fn abs(_: usize, x: f32) f32 {
            return @abs(x);
        }

        fn equals_one(_: usize, x: f32) f32 {
            return @floatFromInt(@intFromBool(x == 1));
        }
        
        fn equals_negative_one(_: usize, x: f32) f32 {
            return @floatFromInt(@intFromBool(x == -1));
        }
    };

    const off = math.sub(box1.lessPos, box2.lessPos);
    const sign = math.doEach(off, util.sign);

    if(yoverlap) {
        return math.mul(sign, .{1, 0});
    }
    
    if(xoverlap) {
        return math.mul(sign, .{0, 1});
    }

    const eql_one = math.doEach(sign, util.equals_one);
    const eql_negative_one = math.doEach(sign, util.equals_negative_one);

    const offset = math.add(math.mul(eql_one, math.sub(box2.greaterPos, box2.lessPos)), math.mul(eql_negative_one, math.sub(box1.greaterPos, box1.lessPos)));

    const corneroffset = math.sub(math.doEach(off, util.abs), offset);

    if(math.cross2(corneroffset, math.mul(sweep, sign)) < 0.0) {
        return math.mul(sign, .{1, 0});
    } else {
        return math.mul(sign, .{0, 1});
    }
}

/// Uses binary search to find the collision time t (∈ [0, 1]) where a sweeping object (defined by the first two parameters) 
/// intersects a stationary object (defined by the third parameter, o2). 
pub fn find_collision_time(o1: anytype, sweep: math.f32x2, o2: @TypeOf(o1), eps: f32, comptime f: fn(@TypeOf(o1), math.f32x2, @TypeOf(o1)) bool) f32 {
    if(f(o1, .{0, 0}, o2)) return 0;
    if(!f(o1, sweep, o2)) return 1;

    var start_time: f32 = 0;
    var end_time: f32 = 1;
    const invEps: f32 = 1.0 / eps;
    const maxIter: usize = 1 + @as(usize, @ceil(@as(f32, @log2(invEps))));
    var i: usize = 0;
    while((end_time - start_time) > eps) {
        if(i >= maxIter) {
            break;
        }
        const mid = (start_time + end_time) / 2.0;
        if(f(o1, math.scale(sweep, mid), o2)) {
            end_time = mid;
        } else {
            start_time = mid;
        }
        i += 1;
    }

    return start_time;
}

test "downward collision test" {
    try std.testing.expectApproxEqAbs(0.5, find_collision_time(Box {.lessPos = .{-10, 10}, .greaterPos = .{10, 20}}, .{0, -20}, .{.lessPos = .{-20, -20}, .greaterPos = .{20, 0}}, 0.01, swept_box_collision), 0.01);
}

test "precision downwards collision tests" {
    try std.testing.expectApproxEqAbs(0.55, find_collision_time(Box {.lessPos = .{-10, 11}, .greaterPos = .{10, 20}}, .{0, -20}, .{.lessPos = .{-20, -20}, .greaterPos = .{20, 0}}, 0.01, swept_box_collision), 0.01);
    try std.testing.expectApproxEqAbs(0.55, find_collision_time(Box {.lessPos = .{-10, 11}, .greaterPos = .{10, 20}}, .{0, -20}, .{.lessPos = .{-20, -20}, .greaterPos = .{20, 0}}, 0.001, swept_box_collision), 0.001);
    try std.testing.expectApproxEqAbs(0.55, find_collision_time(Box {.lessPos = .{-10, 11}, .greaterPos = .{10, 20}}, .{0, -20}, .{.lessPos = .{-20, -20}, .greaterPos = .{20, 0}}, 0.0001, swept_box_collision), 0.0001);
}

