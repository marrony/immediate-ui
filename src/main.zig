const std = @import("std");
const math = std.math;
const vect = @import("vect.zig");

const ray = @cImport({
    @cInclude("raylib.h");
});

fn projectPoint(x: f32, y: f32) ray.Vector2 {
    return .{
        .x = x,
        .y = WindowHeight - y,
    };
}

fn projectPointV(v: vect.Vector2) ray.Vector2 {
    return .{
        .x = v.x,
        .y = WindowHeight - v.y,
    };
}

const Orientation = enum {
    Horizontal,
    Vertical,
};

const Ui = struct {
    const Layout = struct {
        orientation: Orientation,
        position: vect.Vector2,
        maxSize: vect.Vector2,
        size: vect.Vector2,

        pub fn nextPosition(self: *const Layout) vect.Vector2 {
            return switch (self.orientation) {
                .Horizontal => self.position.add(self.size.mult(.{ .x = 1, .y = 0 })),
                .Vertical => self.position.add(self.size.mult(.{ .x = 0, .y = 1 })),
            };
        }

        pub fn addWidget(self: *Layout, size: vect.Vector2) void {
            switch (self.orientation) {
                .Horizontal => {
                    self.size.x += size.x;
                    self.size.y = @max(self.size.y, size.y);
                },
                .Vertical => {
                    self.size.x = @max(self.size.x, size.x);
                    self.size.y += size.y;
                },
            }

            self.size.x = @min(self.size.x, self.maxSize.x);
            self.size.y = @min(self.size.y, self.maxSize.y);
        }
    };

    layouts: std.BoundedArray(Layout, 32),

    pub fn init(comptime N: usize) type {
        return struct {
            layouts: std.BoundedArray(Layout, N) = undefined,

            const Self = @This();

            fn lastLayout(self: *Self) *Layout {
                const len = self.layouts.len;

                if (len > 0) {
                    return &self.layouts.buffer[len - 1];
                } else {
                    @panic("No active layout");
                }
            }

            fn begin(self: *Self, position: vect.Vector2, maxSize: vect.Vector2) !void {
                try self.layouts.append(.{
                    .orientation = .Vertical,
                    .position = position,
                    .maxSize = maxSize,
                    .size = .{ .x = 0, .y = 0 },
                });
            }

            fn end(self: *Self) void {
                if (self.layouts.popOrNull()) |layout| {
                    _ = layout;
                } else {
                    @panic("Unbalanced begin/end calls");
                }
            }

            fn beginLayout(self: *Self, orientation: Orientation) !void {
                var layout = self.lastLayout();
                const position = layout.nextPosition();

                try self.layouts.append(.{
                    .orientation = orientation,
                    .position = position,
                    .maxSize = layout.maxSize,
                    .size = .{ .x = 0, .y = 0 },
                });
            }

            fn endLayout(self: *Self) void {
                if (self.layouts.popOrNull()) |layout| {
                    self.lastLayout().addWidget(layout.size);
                } else {
                    @panic("Unbalanced beginLayout/endLayout calls");
                }
            }

            fn rect(self: *Self, size: vect.Vector2, color: ray.Color) void {
                var layout = self.lastLayout();
                const position = layout.nextPosition();

                drawRect(position, size, color);

                layout.addWidget(size);
            }
        };
    }
};

const UiFlex = struct {
    const Layout = struct {
        orientation: Orientation,
        position: vect.Vector2,
        size: vect.Vector2,
        divisions: []const usize,
        count: usize,

        pub fn nextPosition(self: *Layout) struct { vect.Vector2, vect.Vector2 } {
            var sum: f32 = 0;
            for (self.divisions) |d| {
                sum += @as(f32, @floatFromInt(d));
            }

            const ratio = @as(f32, @floatFromInt(self.divisions[self.count])) / sum;

            const position = self.position;
            const size = switch (self.orientation) {
                .Horizontal => self.size.mult(.{ .x = ratio, .y = 1.0 }),
                .Vertical => self.size.mult(.{ .x = 1.0, .y = ratio }),
            };

            switch (self.orientation) {
                .Horizontal => self.position.x += size.x,
                .Vertical => self.position.y += size.y,
            }

            self.count += 1;

            return .{ position, size };
        }
    };

    layouts: std.BoundedArray(Layout, 32),

    pub fn init(comptime N: usize) type {
        return struct {
            layouts: std.BoundedArray(Layout, N) = undefined,

            const Self = @This();

            fn lastLayout(self: *Self) *Layout {
                const len = self.layouts.len;

                if (len > 0) {
                    return &self.layouts.buffer[len - 1];
                } else {
                    @panic("No active layout");
                }
            }

            fn begin(self: *Self, position: vect.Vector2, size: vect.Vector2, count: []const usize) !void {
                try self.layouts.append(.{
                    .orientation = .Vertical,
                    .position = position,
                    .size = size,
                    .divisions = count,
                    .count = 0,
                });
            }

            fn end(self: *Self) void {
                if (self.layouts.popOrNull()) |layout| {
                    _ = layout;
                } else {
                    @panic("Unbalanced begin/end calls");
                }
            }

            fn beginLayout(self: *Self, orientation: Orientation, count: []const usize) !void {
                var layout = self.lastLayout();

                const position = layout.nextPosition();

                try self.layouts.append(.{
                    .orientation = orientation,
                    .position = position.@"0",
                    .size = position.@"1",
                    .divisions = count,
                    .count = 0,
                });
            }

            fn endLayout(self: *Self) void {
                if (self.layouts.popOrNull()) |layout| {
                    _ = layout;
                } else {
                    @panic("Unbalanced beginLayout/endLayout calls");
                }
            }

            fn rect(self: *Self, color: ray.Color) void {
                var layout = self.lastLayout();
                const position = layout.nextPosition();

                drawRect(position.@"0", position.@"1", color);
                drawRectLine(position.@"0", position.@"1", ray.BLACK);
            }

            fn button(self: *Self, text: []const u8) void {
                var layout = self.lastLayout();
                const position = layout.nextPosition();

                const pos = position.@"0";
                const size = position.@"1";

                drawRect(pos, size, ray.WHITE);

                const m = ray.MeasureTextEx(ray.GetFontDefault(), text.ptr, 16, 1);

                ray.DrawTextEx(
                    ray.GetFontDefault(),
                    text.ptr,
                    .{
                        .x = pos.x + size.x / 2 - m.x / 2,
                        .y = pos.y + size.y / 2 - m.y / 2,
                    },
                    16,
                    1,
                    ray.BLACK,
                );

                drawRectLine(
                    .{
                        .x = pos.x + size.x / 2 - m.x / 2,
                        .y = pos.y + size.y / 2 - m.y / 2,
                    },
                    .{
                        .x = m.x,
                        .y = m.y,
                    },
                    ray.BLACK,
                );
            }

            fn space(self: *Self) void {
                var layout = self.lastLayout();
                const position = layout.nextPosition();

                drawRectLine(position.@"0", position.@"1", ray.BLACK);
            }
        };
    }
};

fn drawRect(upper: vect.Vector2, size: vect.Vector2, color: ray.Color) void {
    ray.DrawRectangleV(
        .{ .x = upper.x, .y = upper.y },
        .{ .x = size.x, .y = size.y },
        color,
    );
}

fn drawRectLine(upper: vect.Vector2, size: vect.Vector2, color: ray.Color) void {
    ray.DrawLineV(
        .{ .x = upper.x, .y = upper.y },
        .{ .x = upper.x + size.x, .y = upper.y + 0 },
        color,
    );
    ray.DrawLineV(
        .{ .x = upper.x + size.x, .y = upper.y + 0 },
        .{ .x = upper.x + size.x, .y = upper.y + size.y },
        color,
    );
    ray.DrawLineV(
        .{ .x = upper.x + size.x, .y = upper.y + size.y },
        .{ .x = upper.x + 0, .y = upper.y + size.y },
        color,
    );
    ray.DrawLineV(
        .{ .x = upper.x + 0, .y = upper.y + size.y },
        .{ .x = upper.x, .y = upper.y },
        color,
    );
}

const WindowWidth = 800;
const WindowHeight = 600;

pub fn main() !void {
    ray.InitWindow(WindowWidth, WindowHeight, "Immediate UI");
    defer ray.CloseWindow();

    ray.SetWindowPosition(0, 0);

    const font = ray.LoadFontEx("fonts/MonacoNerdFont-Regular.ttf", 128, null, 0);
    //ray.SetTextureFilter(font.texture, ray.TEXTURE_FILTER_BILINEAR);
    defer ray.UnloadFont(font);

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.WHITE);

        {
            // flexible layout
            var ui = UiFlex.init(8){};

            try ui.begin(
                .{ .x = 0, .y = 0 },
                .{ .x = WindowWidth / 2, .y = WindowHeight },
                &.{ 1, 1, 1 },
            );

            {
                try ui.beginLayout(.Horizontal, &.{ 1, 2, 1 });
                ui.rect(ray.GREEN);
                ui.button("Text");
                ui.rect(ray.GREEN);
                ui.endLayout();

                ui.space();

                try ui.beginLayout(.Horizontal, &.{ 1, 1, 1 });
                ui.rect(ray.BLUE);
                ui.space();
                ui.rect(ray.BLUE);
                ui.endLayout();
            }

            ui.end();
        }

        {
            // size fixed layout
            var ui = Ui.init(8){};

            try ui.begin(
                .{ .x = WindowWidth / 2, .y = 0 },
                .{ .x = WindowWidth / 2, .y = WindowHeight },
            );

            try ui.beginLayout(.Horizontal);
            ui.rect(.{ .x = WindowWidth / 3, .y = 100 }, ray.RED);
            ui.rect(.{ .x = WindowWidth / 3, .y = 100 }, ray.RED);
            ui.endLayout();

            ui.end();
        }

        ray.EndDrawing();
    }
}
