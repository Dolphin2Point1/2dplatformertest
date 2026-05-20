// this file probably constitutes several warcrimes against zig
// sorry andrew kelley it had to be done
const std = @import("std");
const Io = std.Io;
const testing = std.testing;
const Type = std.builtin.Type;

pub const StorageType = enum {
    DENSE,
    SPARSE,
    SINGLETON
};

pub const Component = struct {
    component_type: type,
    storage_type: StorageType
};

/// Struct holding data for a system. Name and function_type are only used at compile time.
pub const System = struct {
    name: []const u8,
    function: *const anyopaque,
    function_type: type
};

pub fn asSystem(name: []const u8, function: anytype) System {
    const T = @TypeOf(function);
    if(@typeInfo(T) != .@"fn") {
        @compileError("asSystem only accepts functions for systems...");
    }
    return .{.name = name, .function = function, .function_type = T};
}

pub fn World(comptime entity_index_type: type, comptime entity_count: entity_index_type, comptime components: []const Component, comptime systems: []const System) type {
    const field_count = components.len + 1;
    var field_names: [field_count][]const u8 = undefined;
    var field_types: [field_count]type = undefined;
    var field_attrs: [field_count]Type.StructField.Attributes = undefined;
    for (components, 0..) |component, index| {
        if(isHashmap(@TypeOf(component))) {
            @compileError("Component of type " ++ component.component_type ++ " is a Hashmap, which is not allowed!");
        }
        switch(@typeInfo(component.component_type)) {
            .@"struct" => {},
            else => {
                @compileError("Component of type " ++ component.component_type ++ " is not a struct!");
            }
        }
        for (components, 0..) |other_component, other_index| {
            if(index == other_index) continue;
            if(component.component_type == other_component.component_type) {
                @compileError("Only one of each type can be added as a component! Use different structs to circumvent this.");
            }
        }
        field_names[index] = "c_" ++ @typeName(component.component_type);
        field_types[index] = switch(component.storage_type) {
            .DENSE => [entity_count]?component.component_type,
            .SPARSE => std.AutoHashMap(entity_index_type, component.component_type),
            .SINGLETON => component.component_type
        };

        field_attrs[index] = .{};
    }
    
    field_names[field_count - 1] = "next_entity";
    field_types[field_count - 1] = entity_index_type;
    field_attrs[field_count - 1] = .{};
    
    const ff_names = field_names;
    const ff_types = field_types;
    const ff_attrs = field_attrs;

    return struct {
        pub const WorldType = @Struct(.auto, null, &ff_names, &ff_types, &ff_attrs);
        pub const ent_index_type = entity_index_type;
        pub const @"ecs.object_type" = .World;

        pub fn init(alloc: std.mem.Allocator) WorldType {
            var world: WorldType = undefined;
            world.next_entity = 0;
            inline for(components) |component| {
                const wcfn = "c_" ++ @typeName(component.component_type);
                switch(component.storage_type) {
                    .DENSE => @field(world, wcfn) = @splat(null),
                    .SPARSE => @field(world, wcfn) = .init(alloc),
                    .SINGLETON => @field(world, wcfn) = .{}
                }
            }
            return world;
        }

        pub fn deinit(world: *WorldType) void {
            inline for(components) |component| {
                const wcfn = "c_" ++ @typeName(component.component_type);
                switch(component.storage_type) {
                    .SPARSE => {
                        @field(world, wcfn).deinit();
                    },
                    else => {}
                }
            }
        }

        pub fn create_entity(world: *WorldType) entity_index_type {
            const entity = world.next_entity;
            world.next_entity = world.next_entity + 1;
            return entity;
        }

        pub fn attach_component(world: *WorldType, entity: entity_index_type, component: anytype) !void {
            const ct = @TypeOf(component);
            const wcfn = "c_" ++ @typeName(ct);
            switch(@FieldType(WorldType, wcfn)) {
                [entity_count]?ct => @field(world, wcfn)[entity] = component,
                std.AutoHashMap(entity_index_type, ct) => try @field(world, wcfn).put(entity, component),
                ct => @compileError(@typeName(ct) ++ " is a singleton, and cannot be attached as a component!"),
                else => @compileError("Component field " ++ wcfn ++ " does not exist!")
            }
        }

        pub fn tick(world: *WorldType, alloc: std.mem.Allocator) !void {
            inline for(systems) |system| {
                const function_pointer: *const (system.function_type) = comptime @ptrCast(system.function);
                const function = comptime function_pointer.*;
                const function_name = comptime system.name;
                const ArgsType = std.meta.ArgsTuple(system.function_type);
                var args: ArgsType = undefined;
                var arena: std.heap.ArenaAllocator = .init(alloc);
                defer arena.deinit();
                // extract required data
                const params = @typeInfo(system.function_type).@"fn".params;
                inline for (params, 0..) |param, index| {
                    if(param.type == null) {
                        @compileError("Parameter in system function " ++ function ++ " is a generic or unknown type!");
                    }
                    const t = param.type.?;

                    if(comptime isHashmap(t)) {
                        // hashmap query...
                        // guaranteed by isHashmap()
                        const map_types = getPutTypes(t) orelse unreachable;
                        if(map_types.@"0" != entity_index_type) {
                            @compileError("Error in evaulating types for system function" ++ function_name ++ "Hashmaps must have an entity_index_type key (" ++ @typeName(entity_index_type) ++ ")!");
                        }

                        args[index] = try extractHashMap(map_types.@"1", function_name, world, arena.allocator());
                    } else {
                        // treat this like a singleton...
                        if(!isSingletonComponentOrPointer(t, components)) {
                            @compileError("Error in evaluating types for system function " ++ function_name ++ ": Non-singleton " ++ @typeName(t) ++ " can only be accessed via hashmap query!");
                        }
                        comptime var pointer = false;

                        const base_type = comptime ti: switch(@typeInfo(t)) {
                            .pointer => {
                                pointer = true;
                                break :ti @typeInfo(t).pointer.child;
                            },
                            .@"struct" => t,
                            else => @compileError("Error in evaluating types for system function" ++ function_name ++ ": Type" ++ t ++ " in system function is not a struct or a pointer to a struct." )
                        };
                        
                        if(pointer) {
                            args[index] = &@field(world, "c_" ++ @typeName(base_type));
                        } else {
                            args[index] = @field(world, "c_" ++ @typeName(base_type));
                        }
                    }
                }
                @call(.auto, function, args);
            }
        }

        pub fn extractHashMap(comptime V: type, comptime function_name: []const u8, world: *WorldType, alloc: std.mem.Allocator) !std.AutoHashMap(entity_index_type, V) {
            var map: std.AutoHashMap(entity_index_type, V) = .init(alloc);

            if(comptime isNonSingletonComponentOrPointer(V, components)) {
                ent: for(0..entity_count) |entity| {
                    try map.put(@intCast(entity), extractSingleType(V, world, @intCast(entity)) orelse continue :ent);
                }
            } else {
                const members = switch(@typeInfo(V)) {
                    .pointer => |P| @typeInfo(P.child).@"struct".fields,
                    .@"struct" => |S| S.fields,
                    else => unreachable
                };
                inline for(members) |member| {
                    if(comptime !isNonSingletonComponentOrPointer(member.type, components)) {
                        @compileError("Error in evaluating types for system function " ++ function_name ++ ": Query map non-singleton component type " ++ @typeName(V) ++ " contains non-singleton component member " ++ @typeName(member.type) ++ " when all members must be singleton components!");
                    }
                }

                ent: for(0..entity_count) |entity| {
                    var item: V = undefined;
                    inline for(members) |member| {
                        @field(item, member.name) = extractSingleType(member.type, world, @intCast(entity)) orelse continue :ent;
                    }
                    try map.put(@intCast(entity), item);
                }
            }

            return map;
        }

        fn extractSingleType(comptime T: type, world: *WorldType, entity: entity_index_type) ?T {
            comptime var pointer = false;

            const base_type = comptime ti: switch(@typeInfo(T)) {
                .pointer => {
                    pointer = true;
                    break :ti @typeInfo(T).pointer.child;
                },
                .@"struct" => T,
                else => @compileError("Error while creating structs to evaluate types: Type" ++ T ++ " in system function is not a struct or a pointer to a struct." )
            };

            var field = &@field(world, "c_" ++ @typeName(base_type));
            const obj: *base_type = switch(comptime @FieldType(WorldType, "c_" ++ @typeName(base_type))) {
                [entity_count]?base_type => if (field[entity] == null) return null else &(field[entity].?),
                std.AutoHashMap(entity_index_type, base_type) => field.getPtr(@intCast(entity)) orelse return null,
                base_type => @compileError("Singletons such as " ++ T ++ " cannot be extracted."),
                else => @compileError("Field for object " ++ @typeName(base_type) ++ " uses unkown storage type.")
            };


            if(pointer) {
                return obj;
            } else {
                return obj.*;
            }
        }

        pub fn accessDenseComponents(self: *WorldType, comptime T: type) *const [entity_count]T {
            if(comptime !isComponent(T)) {
                @compileError(@typeName(T) ++ " is not a component of this world!");
            }

            if(comptime getComponentStorageType(T) != .DENSE) {
                @compileError(@typeName(T) ++ " is not stored as a dense component!");
            }

            return &@field(self, "c_" ++ @typeName(T));
        }

        pub fn accessSparseComponents(self: *WorldType, comptime T: type) *const std.HashMap(entity_index_type, T) {
            if(comptime !isComponent(T)) {
                @compileError(@typeName(T) ++ " is not a component of this world!");
            }

            if(comptime getComponentStorageType(T) != .DENSE) {
                @compileError(@typeName(T) ++ " is not stored as a sparse component!");
            }

            return &@field(self, "c_" ++ @typeName(T));
        }

        pub fn accessSingleton(self: *WorldType, comptime T: type) *T {
            if(comptime !isComponent(T)) {
                @compileError(@typeName(T) ++ " is not a component of this world!");
            }

            if(comptime getComponentStorageType(T) != .DENSE) {
                @compileError(@typeName(T) ++ " is not stored as a singleton!");
            }

            return &@field(self, "c_" ++ @typeName(T));
        }

        pub fn getComponentStorageType(comptime T: type) StorageType {
            inline for(components) |component| {
                if(T == component.component_type) {
                    return component.storage_type;
                }
            }
            @compileError(@typeName(T) ++ " is not a component of this world!");
        }

        pub fn isComponent(comptime T: type) bool {
            inline for(components) |component| {
                if(T == component.component_type) {
                    return true;
                }
            }
            return false;
        }
    };
}

// TODO remove these and just use isComponent and getComponentStorageType instead...
fn isNonSingletonComponentOrPointer(comptime T: type, comptime components: []const Component) bool {
    return switch(@typeInfo(T)) {
        .pointer => |P| switch(P.size) {
            .one => comptime isNonSingletonComponent(P.child, components),
            .many, .slice, .c => false,
        },
        .@"struct" => isNonSingletonComponent(T, components),
        else => false
    };
}

fn isNonSingletonComponent(comptime T: type, comptime components: []const Component) bool {
    for(components) |component| {
        if(component.component_type == T) {
            if(component.storage_type == .SINGLETON) {
                return false;
            }
            return true;
        }
    }
    return false;
}

fn isSingletonComponentOrPointer(comptime T: type, comptime components: []const Component) bool {
    return switch(@typeInfo(T)) {
        .pointer => |P| switch(P.size) {
            .one => isSingletonComponent(P.child, components),
            .many, .slice, .c => false
        },
        .@"struct" => isSingletonComponent(T, components),
        else => false
    };
}

fn isSingletonComponent(comptime T: type, comptime components: []const Component) bool {
    inline for(components) |component| {
        if(component.component_type == T) {
            if(component.storage_type != .SINGLETON) {
                return false;
            }
            return true;
        }
    }
    return false;
}

fn getPutTypes(comptime T: type) ?struct {type, type} {
    if(!std.meta.hasFn(T, "put")) {
        return null;
    }
    
    const params = @typeInfo(@TypeOf(T.put)).@"fn".params;
    if(params.len != 3 and params[0] == T) {
        return null;
    }

    return .{ params[1].type orelse return null, params[2].type orelse return null };
}

// TODO make this use proper duck typing so that other hashmaps can be used (and add a declaration to disable detection)
fn isHashmap(comptime T: type) bool {
    const temp = comptime getPutTypes(T);
    const putTypes = temp orelse return false;

    return T == std.AutoHashMap(putTypes.@"0", putTypes.@"1");
}

// TESTS ONLY AFTER THIS POINT
const Health = struct {
    health: u8
};

test "World type test" {
    const Player = struct {
        controller: u8
    };
    const ExpectedWorldType = struct {
        c_health: [16]?Health,
        c_player: std.AutoHashMap(u8, ?Health),
        next_entity: u8
    };
    const WorldType = World(u8, 16, &[_]Component{.{.component_type = Health, .storage_type = .DENSE}, .{.component_type = Player, .storage_type = .SPARSE}}, &[_]System{}).WorldType;
    try testing.expectEqual([16]?Health, @typeInfo(WorldType).@"struct".fields[0].type);
    try testing.expectEqualStrings("c_" ++ @typeName(Health), @typeInfo(WorldType).@"struct".fields[0].name);
    try testing.expectEqual(std.AutoHashMap(u8, Player), @typeInfo(WorldType).@"struct".fields[1].type);
    try testing.expectEqualStrings("c_" ++ @typeName(Player), @typeInfo(WorldType).@"struct".fields[1].name);
    try testing.expectEqual(u8, @typeInfo(WorldType).@"struct".fields[2].type);
    try testing.expectEqualStrings("next_entity", @typeInfo(WorldType).@"struct".fields[2].name);
    try testing.expectEqual(@sizeOf(ExpectedWorldType), @sizeOf(WorldType));
}

fn lose_health(health: std.AutoHashMap(u8, *Health)) void {
    var iter = health.valueIterator();
    while (iter.next()) |value| {
        (value.*).health -= 1;
    }
}

test "System test" {
    const WorldData = World(u8, 16, &[_]Component{.{ .component_type = Health, .storage_type = .DENSE}}, 
        &[_]System{asSystem("lose_health", lose_health)});
    var alloc: std.heap.DebugAllocator(.{}) = .init;
    var world: WorldData.WorldType = WorldData.init(alloc.allocator());
    defer WorldData.deinit(&world);
    const ent = WorldData.create_entity(&world);
    try WorldData.attach_component(&world, ent, Health { .health = 10 });
    try WorldData.tick(&world, alloc.allocator());
    try testing.expectEqual(9, @field(world, "c_" ++ @typeName(Health))[0].?.health);
}

const Other = struct {};

fn lose_health_2(health: std.AutoHashMap(u8, struct {*Health, Other})) void {
    var iter = health.valueIterator();
    while (iter.next()) |value| {
        value.@"0".health -= 1;
    }
}

test "Multisystem test" {
    const WorldData = World(u8, 16, &[_]Component{.{ .component_type = Health, .storage_type = .DENSE }, .{ .component_type = Other, .storage_type = .DENSE }}, &[_]System{asSystem("lose_health_2", lose_health_2)});
    var alloc: std.heap.DebugAllocator(.{}) = .init;
    var world: WorldData.WorldType = WorldData.init(alloc.allocator());
    defer WorldData.deinit(&world);
    const ent = WorldData.create_entity(&world);
    try WorldData.attach_component(&world, ent, Health { .health = 10 });
    try WorldData.attach_component(&world, ent, Other {});
    const ent2 = WorldData.create_entity(&world);
    try WorldData.attach_component(&world, ent2, Health { .health = 10 });
    try WorldData.tick(&world, alloc.allocator());
    try testing.expectEqual(9, @field(world, "c_" ++ @typeName(Health))[0].?.health);
    try testing.expectEqual(10, @field(world, "c_" ++ @typeName(Health))[1].?.health);
}
