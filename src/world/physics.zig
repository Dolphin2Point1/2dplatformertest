const std = @import("std");

const ecs = @import("../engine/ecs.zig");
const world = @import("world.zig");
const math = @import("../engine/math.zig");
const player = @import("player.zig");

pub const components = [_]ecs.Component {
    .{.component_type = PositionDerivatives, .storage_type = .SPARSE},
    .{.component_type = GravityAffected, .storage_type = .SPARSE},
    .{.component_type = WorldPhysicsConstants, .storage_type = .SINGLETON}
};

pub const early_physics_systems = [_]ecs.System {
    ecs.asSystem("reset_acceleration", reset_acceleration)
};

pub const physics_update_systems = [_]ecs.System {
    ecs.asSystem("apply_gravity", apply_gravity)
} ++ player.systems;

pub const late_physics_update_systems = [_]ecs.System {
    ecs.asSystem("update_positions", update_positions)
};

pub const PositionDerivatives = struct {
    vel: math.f32x2 = @splat(0),
    accel: math.f32x2 = @splat(0),
};

pub const WorldPhysicsConstants = struct {
    gravity: math.f32x2 = .{0, -100}
};

pub const GravityAffected = struct {};

fn reset_acceleration(query: std.AutoHashMap(world.entity_id_type, *PositionDerivatives)) void {
    var iter = query.valueIterator();
    while (iter.next()) |derivatives| {
        derivatives.*.accel = @splat(0);
    }
}

fn apply_gravity(query: std.AutoHashMap(world.entity_id_type, struct {*PositionDerivatives, GravityAffected}), world_physics: WorldPhysicsConstants) void {
    var iter = query.valueIterator();
    while (iter.next()) |derivatives| {
        derivatives.@"0".accel = math.add(derivatives.@"0".accel, world_physics.gravity);
    }
}

fn update_positions(positions: std.AutoHashMap(world.entity_id_type, struct {*world.Position, *PositionDerivatives}), data: world.TickData) void {
    var iter = positions.valueIterator();
    while (iter.next()) |item| {
        const position: *world.Position = item.@"0";
        const derivatives: *PositionDerivatives = item.@"1";
        position.last_pos = position.pos;
        derivatives.vel = math.add(derivatives.vel, math.scale(derivatives.accel, 0.5 * data.dt));
        position.pos    = math.add(position.pos,    math.scale(derivatives.vel, data.dt));
        derivatives.vel = math.add(derivatives.vel, math.scale(derivatives.accel, 0.5 * data.dt));
    }
}

