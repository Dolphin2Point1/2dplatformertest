pub const f32x2 = @Vector(2, f32);

pub inline fn swap2(v: f32x2) f32x2 {
    return @shuffle(f32, v, undefined, .{ 1, 0 });
}

pub inline fn conjugate2(v: f32x2) f32x2 {
    return v * .{1, -1};
}

pub inline fn dot2(v0: f32x2, v1: f32x2) f32 {
    return @reduce(.Add, v0 * v1);
}

pub inline fn cross2(v0: f32x2, v1: f32x2) f32 {
    return @reduce(.Add, v0 * conjugate2(swap2(v1)));
}

pub inline fn length2(v: f32x2) f32 {
    return dot2(v, v);
}

pub inline fn normalize2(v: f32x2) f32x2 {
    return v / length2(v);
}



