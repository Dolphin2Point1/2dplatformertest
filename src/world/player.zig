const std = @import("std");

const ecs = @import("../engine/ecs.zig");
const physics = @import("physics.zig");
const world = @import("world.zig");

pub const components = [_]ecs.Component {
    .{.component_type = Controller, .storage_type = .SINGLETON},
    .{.component_type = Player, .storage_type = .SPARSE}
};

pub const systems = [1]ecs.System {
    ecs.asSystem("player.player_control", player_control)
};

pub const Controller = struct {
    left: bool = false,
    right: bool = false,
    jump: bool = false
};

pub const Player = struct {};

fn player_control(positions: std.AutoHashMap(world.entity_id_type, struct {*physics.PositionDerivatives, Player}), controller: Controller) void {
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
            item.@"0".vel[1] = 20;
        }
    }
}
