

# A Simple VM in zig
code from https://www.andreinc.net/2021/12/01/writing-a-simple-vm-in-less-than-125-lines-of-c

下面是阅读实现vm时的一些笔记

## The Instructions

从zig语言的视角来看，指令就是`u16`整数。目前实现的VM中只有16个指令。

![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/instr.drawio.png)

前四个bits是OpCode指令，剩下的12个bits是参数。

可以使用下面函数来提取指令。

```zig
// 右偏移12位，拿到指令码
inline fn OPC(i: u16) u16 {
    return i >> 12;
}
```

![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/opp.drawio.png)

因为OpCode使用4bits表示，最大指令数量就是16(2^4=15)。

我们在zig中使用一个函数指针数组对应到OpCode操作。

```zig
// 指令操作函数类型
const op_ex_f = fn (i: u16) void;

// 指令操作add函数
fn br(i: u16) void {
    if ((reg[@enumToInt(regist.RCND)] & FCND(i)) > 0) {
        reg[@enumToInt(regist.RPC)] += 1;
    }
}

// .... other 操作函数

const op_ex = [NOPS]op_ex_f{
  br, add, ld, st, jsr, and, ldr, str, rti, not, ldi, sti, jmp, res, lea, trap 
};

```

现在所有的指令可以通过下面的方式执行

```
op_ex[OP(instr)](instr);
```

下面是LC3实现的指令码：

|Instruction|OpCode Hex|	OpCode Bin|	C function	|Comments|
|-------|---|---|---|---|
|br|0x0|0b0000|void br(uint16_t i)|Conditional branch|
|add|0x1|0b0001|void and(uint16_t i)|Used for addition.|
|ld|0x2|0b0010|void ld(uint16_t i)|Load RPC + offset|
|st|0x3|0b0011|void st(uint16_t i)|Store|
|jsr|0x4|0b0100|void jsr(uint16_t i)|Jump to subroutine|
|and|0x5|0b0101|void and(uint16_t i)|Bitwise logical AND|
|ldr|0x6|0b0110|void ldr(uint16_t i)|Load Base+Offset|
|str|0x7|0b0111|void str(uint16_t i)|Store base + offset|
|rti|0x8|0b1000|void rti(uint16_t i)|Return from interrupt (not implemented)|
|not|0x9|0b1001|void not(uint16_t i)|Bitwise complement|
|ldi|0xA|0b1010|void ldi(uint16_t i)|Load indirect|
|sti|0xB|0b1011|void sti(uint16_t i)|Store indirect|
|jmp|0xC|0b1100|void jmp(uint16_t i)|Jump/Return to subroutine|
| |0xD|0b1101| |Unused OpCode|
|lea|0xE|0b1110|void lea(uint16_t i)|Load effective address|
|trap|0xF|0b1111|void trap(uint16_t i)|System trap/call|


我们可以将指令分成四种类型：

- `br`， `jmp`， `jsr` 属于控制流类型，跳转到特定的指令语句(类似go to语句)或者条件跳转
- `ld`,`ldr`,`ldi`,`lea` 用于从主内存中加载数据到寄存器
- `st`,`str`,`sti` 用于从寄存器中加载数据到主内存
- `add`,`and`,`not`用于处理数据操作，操作完之后数据仍在寄存器中。


关于一些副作用的寄存器:

`RCND` 条件寄存器标志位，用于追踪一些指令的额外信息。在我们的实现中它可以有三个值：
- `1<<0` (P正数) 如果最后一个操作产生整数结果
- `1<<1` (Z0) 如果最后一个操作产生0
- `1<<2` (N负数) 如果最后一个操作产生负数

通过判断该寄存器的值，我们可以实现代码跳转，达到高阶语言的`IF`语句。

代码实现：

```zig
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
```

### Add - Adding two values

![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/add.drawio.png)

![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/add2.drawio.png)

通过图片我们可以看出有两个版本的`add`，通过第五个bit位标识不同。

`add1` 将`SR1`和`SR2`的值加起来，然后存至`DR1`寄存器

`add2` 将 `IMM5`和`SR1`加起来，存至`DR1`寄存器。

`IMM5`寄存器是一个5位的正负数。最重要的bit是符号位。在实现代码的时候我们需要考虑到这点。我们需要写一个函数一个函数扩展符号让它和16bits形式兼容。下面的函数实际上是转换成16bit有符号格式。

```zig
inline fn IMM(i: u16) u16 {
    return i & 0x1F;
}

inline fn SEXTIMM(i: u16) u16 {
    return sext(IMM(i), 5);
}

fn sext(n: u16, b: comptime_int) u16 {
    return 
        if ((n >> (b - 1) & 1) > 0)
             0 | 0xFFFF << b)
        else n;
}
```


下面的方法是一个提取`add`第5个bit位的值
```zig
inline fn FIMM(i: u16) u16 {
    return i >> 5 & 1;
}
```

我们来分析下提取过程
- 首先是将i右移5bits
- 将最后一bit和1做`&`操作

![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/fimm.drawio.png)

### and - Bitwise logical AND

### ld - Load RPC + offset

![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/ldexp.drawio.png)

该指令从主内存加载数据到目的寄存器，获取到内存位置的数据后作为偏移值加到`RPC`寄存器中.`ld`并不会修改`RPC`的值，仅仅是引用它。

![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/ldexp.drawio.png)



![](https://www.andreinc.net/assets/images/2021-12-01-writing-a-simple-vm-in-less-than-125-lines-of-c/ld.drawio.png)

