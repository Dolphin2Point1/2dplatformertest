const std = @import("std");

const ecs = @import("../engine/ecs.zig");
const math = @import("../engine/math.zig");

pub const Position = struct {
    pos: math.f32x2
};

pub const Sprite = struct {
    sprite: u32
};

pub const Controller = struct {
    left: bool = false,
    right: bool = false,
    jump: bool = false
};

pub const PositionDerivatives = struct {
    vel: math.f32x2 = @splat(0),
    accel: math.f32x2 = @splat(0),
};

pub const WorldPhysicsConstants = struct {
    gravity: math.f32x2 = .{0, -100}
};

pub const GravityAffected = struct {};

pub const TickData = struct {
    dt: f32
};

pub const Player = struct {};

fn reset_acceleration(query: std.AutoHashMap(entity_id_type, *PositionDerivatives)) void {
    var iter = query.valueIterator();
    while (iter.next()) |derivatives| {
        derivatives.*.accel = @splat(0);
    }
}

fn apply_gravity(query: std.AutoHashMap(entity_id_type, struct {*PositionDerivatives, GravityAffected}), world_physics: WorldPhysicsConstants) void {
    var iter = query.valueIterator();
    while (iter.next()) |derivatives| {
        derivatives.@"0".accel += world_physics.gravity;
    }
}

fn update_positions(positions: std.AutoHashMap(entity_id_type, struct {*Position, *PositionDerivatives}), data: TickData) void {
    var iter = positions.valueIterator();
    while (iter.next()) |item| {
        const position: *Position = item.@"0";
        const derivatives: *PositionDerivatives = item.@"1";
        derivatives.vel += @as(math.f32x2, @splat(0.5 * data.dt)) * derivatives.accel;
        position.pos +=    @as(math.f32x2, @splat(data.dt))       * derivatives.vel;
        derivatives.vel += @as(math.f32x2, @splat(0.5 * data.dt)) * derivatives.accel;
    }
}

fn player_control(positions: std.AutoHashMap(entity_id_type, struct {*PositionDerivatives, Player}), controller: Controller) void {
    var iter = positions.valueIterator();
    while (iter.next()) |item| {
        var input: f32 = 0;
        if(controller.right) {
            input += 1;
        }
        if(controller.left) {
            input -= 1;
        }

        item.@"0".accel += .{input * 50, 0};
        if(controller.jump) {
            item.@"0".vel[1] = 10;
        }
    }
}


const components = [_]ecs.Component {
    .{.component_type = Position, .storage_type = .DENSE},
    .{.component_type = PositionDerivatives, .storage_type = .SPARSE},
    .{.component_type = GravityAffected, .storage_type = .SPARSE},
    .{.component_type = Sprite, .storage_type = .SPARSE},
    .{.component_type = Player, .storage_type = .SPARSE},
    .{.component_type = Controller, .storage_type = .SINGLETON},
    .{.component_type = WorldPhysicsConstants, .storage_type = .SINGLETON}
};

const systems = [_]ecs.System {
    ecs.asSystem("reset_acceleration", reset_acceleration),
    ecs.asSystem("apply_gravity", apply_gravity),
    ecs.asSystem("player_control", player_control),
    ecs.asSystem("update_positions", update_positions),
};

pub const entity_id_type = u16;
pub const entity_count: entity_id_type = 256;

pub const WorldFn = ecs.World(entity_id_type, entity_count, &components, &systems, TickData);
pub const World = WorldFn.WorldType;
