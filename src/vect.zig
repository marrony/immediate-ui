const std = @import("std");
const math = std.math;

pub const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn format(self: *const Vector2, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{{{d:.3},{d:.3}}}", .{ self.x, self.y });
    }

    pub fn dot(self: Vector2, other: Vector2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn length2(self: Vector2) f32 {
        return dot(self, self);
    }

    pub fn length(self: Vector2) f32 {
        return math.sqrt(self.length2());
    }

    pub fn scale(self: Vector2, k: f32) Vector2 {
        return .{
            .x = self.x * k,
            .y = self.y * k,
        };
    }

    pub fn negate(self: Vector2) Vector2 {
        return .{
            .x = -self.x,
            .y = -self.y,
        };
    }

    pub fn sub(self: Vector2, other: Vector2) Vector2 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }

    pub fn add(self: Vector2, other: Vector2) Vector2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn mult(self: Vector2, other: Vector2) Vector2 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    pub fn div(self: Vector2, other: Vector2) Vector2 {
        return .{
            .x = self.x / other.x,
            .y = self.y / other.y,
        };
    }

    pub fn normalize(self: Vector2) Vector2 {
        return self.scale(1 / self.length());
    }

    pub fn lerp(a: Vector2, b: Vector2, t: f32) Vector2 {
        const k0 = a.scale(1 - t);
        const k1 = b.scale(t);
        return k0.add(k1);
    }
};
