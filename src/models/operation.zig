const std = @import("std");

const Self = @This();
pub const Operand = enum { sum, diff, product, division, remainder };

a: i32 = 0,
b: i32 = 0,
operand: Operand = Operand.sum,
result: ?f32,

pub fn init(random: std.Random) Self {
    const a = random.intRangeAtMost(i32, -9999, 9999);
    var b = random.intRangeAtMost(i32, -9999, 9999);

    const operand: Operand = switch (random.intRangeAtMost(u8, 1, 5)) {
        1 => .sum,
        2 => .diff,
        3 => .product,
        4 => blk: {
            if (b == 0) b = 1;
            break :blk .division;
        },
        5 => blk: {
            if (b == 0) b = 1;
            break :blk .remainder;
        },
        else => unreachable,
    };

    return .{
        .a = a,
        .b = b,
        .operand = operand,
        .result = null,
    };
}

pub fn calculate(self: *Self) void {
    if (self.result != null) return;

    const a: f32 = @floatFromInt(self.a);
    const b: f32 = @floatFromInt(self.b);

    self.result = switch (self.operand) {
        .sum => a + b,
        .diff => a - b,
        .product => a * b,
        .division => a / b,
        .remainder => @mod(a, b),
    };
}

pub fn toString(self: Self, alloc: std.mem.Allocator, displayResult: bool) ![]const u8 {
    const operand: u8 =
        switch (self.operand) {
            .sum => '+',
            .diff => '-',
            .product => '*',
            .division => '/',
            .remainder => '%',
        };

    var op = try alloc.print("{d} {c} {d}", .{ self.a, operand, self.b });
    if (displayResult) {
        var res: []const u8 = undefined;
        if (self.result == null) {
            res = try alloc.dupe(u8, " = ERROR");
        } else {
            res = try alloc.print(" = {d:.4}", .{self.result.?});
        }
        defer alloc.free(res);

        const prevMem = (&op).*;
        defer alloc.free(prevMem);

        op = try std.mem.concat(alloc, u8, &.{ op, res });
    }
    return op;
}

pub fn isInvalid(self: *Self) bool {
    return (self.operand == .division and self.b == 0);
}

pub const ParsingError = error{ InvalidOperation, DivisionByZero, Overflow, InvalidCharacter };
pub fn fromString(str: []const u8) ParsingError!Self {
    var op_index: ?usize = null;
    var op_type: ?Operand = null;
    var op_len: usize = 1; // Track operator length to slice 'b' correctly
    var i: usize = 0;

    // Skip leading whitespace
    while (i < str.len and std.ascii.isWhitespace(str[i])) : (i += 1) {}

    // Skip a leading '+' or '-'
    if (i < str.len and (str[i] == '-' or str[i] == '+')) {
        i += 1;
    }

    while (i < str.len) : (i += 1) {
        if (std.mem.startsWith(u8, str[i..], "mod")) {
            op_type = .remainder;
            op_index = i;
            op_len = 3;
            break;
        }

        switch (str[i]) {
            '+' => {
                op_type = .sum;
                op_index = i;
                break;
            },
            '-' => {
                op_type = .diff;
                op_index = i;
                break;
            },
            '*', 'x' => {
                op_type = .product;
                op_index = i;
                break;
            },
            '/' => {
                op_type = .division;
                op_index = i;
                break;
            },
            '%' => {
                op_type = .remainder;
                op_index = i;
                break;
            },
            else => continue,
        }
    }

    if (op_index == null or op_type == null) {
        return error.InvalidOperation;
    }

    const idx = op_index.?;

    // Split string and trim whitespace on both ends of both operands
    const a_str = std.mem.trim(u8, str[0..idx], &std.ascii.whitespace);
    const b_str = std.mem.trim(u8, str[idx + op_len ..], &std.ascii.whitespace);

    const a = try std.fmt.parseInt(i32, a_str, 10);
    const b = try std.fmt.parseInt(i32, b_str, 10);

    if (op_type.? == .division and b == 0) return error.DivisionByZero;

    return Self{
        .a = a,
        .b = b,
        .operand = op_type.?,
        .result = null,
    };
}
