const std = @import("std");

const ecs = @import("../engine/ecs.zig");
const math = @import("../engine/math.zig");
const physics = @import("physics.zig");
const player = @import("player.zig");

pub const Position = struct {
    pos: math.f32x2,
    last_pos: math.f32x2 = undefined
};

pub const Sprite = struct {
    sprite: u32
};

pub const TickData = struct {
    dt: f32
};

const basic_components = [_]ecs.Component {
    .{.component_type = Position, .storage_type = .DENSE},
    .{.component_type = Sprite, .storage_type = .SPARSE}
};
const components = basic_components ++ physics.components ++ player.components;

const systems = physics.early_physics_systems ++ physics.physics_update_systems ++ physics.late_physics_update_systems;

pub const entity_id_type = u16;
pub const entity_count: entity_id_type = 256;

pub const WorldFn = ecs.World(entity_id_type, entity_count, &components, &systems, TickData);
pub const World = WorldFn.WorldType;
