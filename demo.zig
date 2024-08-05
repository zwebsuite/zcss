const std = @import("std");

const zcss = @import("./src/zcss.zig");
const CSSParser = zcss.Parser;

const vexlib = @import("vexlib");
const println = vexlib.println;

pub fn main() void {
    // setup allocator
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = generalPurposeAllocator.deinit();
    const allocator = generalPurposeAllocator.allocator();
    vexlib.init(&allocator);

    const cssFile = @embedFile("./test/test.css");

    var myParser = CSSParser{};
    const ast = myParser.parse(cssFile) catch |err| blk: {
        switch (err) {
            error.ExpectedEndOfComment => {
                println("ExpectedEndOfComment");
            },
            error.ExpectedSelector => {
                println("ExpectedSelector");
            },
            error.ExpectedBlock => {
                println("ExpectedBlock");
            },
            error.ExpectedDeclaration => {
                println("ExpectedDeclaration");
            },
            error.ExpectedColon => {
                println("ExpectedColon");
            },
        }
        break :blk zcss.Stylesheet{
            .rules = undefined,
            .comments = undefined
        };
    };
    
    // std.debug.print("AST:\n{}\n", .{ast});
    // println("BEFORE:");
    // println(cssFile);

    var stringified = zcss.stringify(ast);
    defer stringified.dealloc();
    println("AFTER:");
    println(stringified);

    zcss.deallocAST(ast);
}
