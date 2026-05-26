pub const f32x2 = [2]f32;

pub fn vectorBaseType(comptime v_type: type) type {
    return switch (@typeInfo(v_type)) {
        .pointer => |P| switch(P) {
            .slice => P.child,
            else => @compileError(@typeName(v_type) ++ " is not a vector type!")
        },
        .array => |a| a.child,
        .vector => |v| v.child,
        else => @compileError(@typeName(v_type) ++ " is not a vector type!")
    };
}

pub fn vectorLength(vector: anytype) usize {
    return switch(@typeInfo(@TypeOf(vector))) {
        .pointer => |P| switch(P) {
            .slice => vector.len,
            else => @compileError(@typeName(@TypeOf(vector)) ++ " is not a vector type!")
        },
        .array => |a| a.len,
        .vector => |v| v.len,
        else => @compileError(@typeName(@TypeOf(vector)) ++ " is not a vector type!")
    };
}

pub inline fn doEach(v: anytype, comptime f: fn(usize, vectorBaseType(@TypeOf(v))) vectorBaseType(@TypeOf(v))) @TypeOf(v) {
    var out: @TypeOf(v) = undefined;
    for (0..vectorLength(v)) |i| {
        out[i] = f(i, v[i]);
    }
    return out;
}

pub inline fn rotate2D90DegCCW(v: f32x2) f32x2 {
    return .{-v[1], v[0]};
}

pub inline fn rotate2D90DegCW(v: f32x2) f32x2 {
    return .{v[1], -v[0]};
}

pub inline fn negate(v: anytype) @TypeOf(v) {
    var out = v;
    for (0..vectorLength(v)) |i| {
        out[i] *= -1;
    }
    return out;
}

pub inline fn add(v0: anytype, v1: @TypeOf(v0)) @TypeOf(v0) {
    if(vectorLength(v0) != vectorLength(v0)) {
        @panic("Summed vectors must have the same length!");
    }
    var out = v0;
    for (0..vectorLength(out)) |i| {
        out[i] += v1[i];
    }
    return out;
}

pub inline fn sub(v0: anytype, v1: @TypeOf(v0)) @TypeOf(v0) {
    return add(v0, negate(v1));
}

pub inline fn mul(v0: anytype, v1: @TypeOf(v0)) @TypeOf(v0) {
    if(vectorLength(v0) != vectorLength(v1)) {
        @panic("Multiplied vectors must have the same length!");
    }
    var out = v0;
    for (0..vectorLength(out)) |i| {
        out[i] *= v1[i];
    }
    return out;
}

pub inline fn scale(v: anytype, s: anytype) @TypeOf(v) {
    var out = v;
    for(0..vectorLength(v)) |i| {
        out[i] *= s;
    }
    return out;
}

pub inline fn reduceAdd(v: anytype) vectorBaseType(@TypeOf(v)) {
    var out: vectorBaseType(@TypeOf(v)) = 0;
    for(0..vectorLength(v)) |i| {
        out += v[i];
    }
    return out;
}

pub inline fn reduceMul(v: anytype) vectorBaseType(@TypeOf(v)) {
    var out: vectorBaseType(@TypeOf(v)) = 0;
    for(0..vectorLength(v)) |i| {
        out += v[i];
    }
    return out;
}

pub inline fn swap2(v: f32x2) f32x2 {
    return .{v[1], v[0]};
}

pub inline fn conjugate2(v: f32x2) f32x2 {
    return .{v[0], -v[1]};
}

pub inline fn dot(v0: anytype, v1: @TypeOf(v0)) vectorBaseType(@TypeOf(v0)) {
    return reduceAdd(mul(v0, v1));
}

pub inline fn cross2(v0: f32x2, v1: f32x2) f32 {
    return reduceAdd(dot(v0, rotate2D90DegCW(v1)));
}

pub inline fn sqrLength(v: anytype) vectorBaseType(@TypeOf(v)) {
    return dot(v, v);
}

pub inline fn length(v: anytype) vectorBaseType(@TypeOf(v)) {
    return @sqrt(sqrLength(v));
}

pub inline fn normalize2(v: anytype) vectorBaseType(@TypeOf(v)) {
    return scale(v, 1 / length(v));
}

