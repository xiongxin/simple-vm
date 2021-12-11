const std = @import("std");

const NOPS = 16; // number of instructions

inline fn OPC(i: u16) u16 {
    return i >> 12;
}

inline fn FCND(i: u16) u16 {
    return (i >> 9) & 0x7;
}

inline fn IMM(i: u16) u16 {
    return i & 0x1F;
}

inline fn SEXTIMM(i: u16) u16 {
    return sext(i & 0x3f, 6);
}

/// As a convention, we should start loading programs
/// into the main memory from 0x3000 onwards.
const PC_START = 0x3000;
/// MAIN MEMOERY
var mem: [std.math.maxInt(u16)]u16 = undefined;

/// OpCode functions
const op_ex_f = fn (i: u16) void;
const op_ex = [NOPS]op_ex_f{br};

/// Registers Types
/// R0 is a general-purpose register
/// We are going to also use it for reading/writing data from/to stdin/stdout;
/// R1, R2,..R7 are general purpose registers;
/// RPC is the program counter register.It contains 
/// the memory address of the next instruction we will execute.
/// RCND is the conditional register. 
/// The conditional flag gives us information about the 
/// previous operation that happened at ALU level in the CPU.
/// RCNT is the register count
/// to access a register, we simply: reg[@enumToInt(.R0)]
const regist = enum(u8) { R0 = 0, R1, R2, R3, R4, R5, R6, R7, RPC, RCND, RCNT };

/// Register
var reg: [@enumToInt(regist.RCNT)]u16 = undefined;

/// RCND寄存器标志位
const flags = enum(u8) { FP = 1 << 0, FZ = 1 << 1, FN = 1 << 2 };

/// RCND赋值操作
fn uf(r: regist) void {
    if (reg[@enumToInt(r)] == 0) {
        reg[@enumToInt(regist.RCND)] = @enumToInt(flags.FZ); // the value in r is zero
    } else if ((reg[@enumToInt(r)] >> 15) > 0) {
        reg[@enumToInt(regist.RCND)] = @enumToInt(flags.FN); // the value in r is z negative number
    } else {
        reg[@enumToInt(regist.RCND)] = @enumToInt(flags.FP); // the value in r is a positive number
    }
}

fn br(i: u16) void {
    if ((reg[@enumToInt(regist.RCND)] & FCND(i)) > 0) {
        reg[@enumToInt(regist.RPC)] += 1;
    }
}

/// read from main memory
inline fn mr(address: u16) u16 {
    return mem[address];
}

/// write from main memory
inline fn mw(address: u16, val: u16) void {
    mem[address] = val;
}

fn sext(n: u16, b: comptime_int) u16 {
    return if ((n >> (b - 1) & 1) > 0) 0 | (0xFFFF << b) else n;
}

//////////////////////////////////////////////

fn test_op_ex_f(i: u16) void {
    std.debug.print("...{d}....", .{i});
}

test "max u16" {
    try std.testing.expect(std.math.maxInt(u16) == 65535);
    try std.testing.expect(reg.len == 10);

    var arr = [_]u16{ 1, 2 };
    arr[1] += 1;
    try std.testing.expect(arr[1] == 3);

    const op_ex_test = [_]op_ex_f{test_op_ex_f};
    op_ex_test[0](17);
}
