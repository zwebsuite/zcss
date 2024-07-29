// zcss - Pure Zig CSS Parser
// https://www.w3.org/TR/css-syntax-3/

const std = @import("std");
const vexlib = @import("./lib/vexlib.zig");
const As = vexlib.As;
const Math = vexlib.Math;
const String = vexlib.String;
const Array = vexlib.Array;
const fmt = vexlib.fmt;

const ParseError = error {
    ExpectedEndOfComment,
    ExpectedSelector,
    ExpectedBlock,
    ExpectedColon,
    ExpectedDeclaration
};

const Position = struct {
    line: u32,
    column: u32
};

const PositionRange = struct {
    start: Position,
    end: Position
};

const Declaration = struct {
    property: String,
    value: String,
    position: PositionRange
};

const Rule = struct {
    selectors: Array(String),
    declarations: Array(Declaration),
    parent: ?*Rule,
    childRules: Array(Rule),
    position: PositionRange,
};

const Comment = struct {
    value: String,
    position: PositionRange,
};


// seperate out comments for better cache locality since the engine never needs them
pub const Stylesheet = struct {
    rules: Array(Rule),
    comments: Array(Comment)
};

pub const Parser = struct {
    css: String = undefined,
    comments: Array(Comment) = undefined,
    linenum: u32 = 1,
    column: u32 = 1,

    fn updatePosition(self: *Parser, str_: String) void {
        var str = str_;
        var idx: u32 = 0;
        const len = str.len();
        while (idx < len) : (idx += 1) {
            switch (str.charAt(idx)) {
                '\n' => {
                    self.linenum += 1;
                    self.column = 0;
                },
                else => {
                    self.column += 1;
                }
            }
        }
    }

    fn position(self: *Parser) Position {
        return Position{
            .line = self.linenum,
            .column = self.column
        };
    }

    fn skipWhitespace(self: *Parser) void {
        var idx: u32 = 0;
        while (true) {
            const len = self.css.len();
            if (idx < len) {
                switch (self.css.charAt(idx)) {
                    ' ', '\t', '\n', '\r', => {
                        idx += 1;
                    },
                    else => break
                }
            } else {
                break;
            }
        }
        self.updatePosition(self.css.slice(0, idx));
        self.css = self.css.slice(idx, 0);
    }

    fn comment(self: *Parser) ParseError!Comment {
        const commentEnd = self.css.indexOf("*/");
        if (commentEnd == -1) {
            return ParseError.ExpectedEndOfComment;
        }

        const startPos = self.position();
        const commentValue = self.css.slice(2, As.u32(commentEnd));
        self.updatePosition(commentValue);
        self.css = self.css.slice(As.u32(commentEnd) + 2, 0);

        const commentAST = Comment{
            .value = commentValue,
            .position = PositionRange{
                .start = startPos,
                .end = self.position()
            }
        };

        return commentAST;
    }

    fn skipComments(self: *Parser) ParseError!void {
        while (self.css.charAt(0) == '/' and self.css.charAt(1) == '*') {
            self.comments.append(try self.comment());
        }
    }

    fn declaration(self: *Parser, colonIdx: u32) ParseError!Declaration {
        var property = self.css.slice(0, colonIdx);

        var idx = colonIdx + 1;
        while (true) {
            if (idx == self.css.len()) {
                return ParseError.ExpectedDeclaration;
            }

            const ch0 = self.css.charAt(idx);
            if (ch0 == ';' or ch0 == '}') {
                break;
            }
            idx += 1;
        }

        var value = self.css.slice(colonIdx + 1, idx);

        const startPos = self.position();

        self.updatePosition(self.css.slice(0, idx + 1));
        self.css = self.css.slice(idx + 1, 0);

        return Declaration{
            .property = property.trim(),
            .value = value.trim(),
            .position = PositionRange{
                .start = startPos,
                .end = self.position()
            }
        };
    }

    fn selectors(self: *Parser) ParseError!Array(String) {
        var selectorsArr = Array(String).alloc(1);
        var idx: u32 = 0;
        while (true) {
            const ch0 = self.css.charAt(idx);
            if (ch0 == '{') {
                // move to start of block
                var sel = self.css.slice(0, idx);
                const trimed = sel.trim();
                selectorsArr.append(trimed);

                self.updatePosition(sel);
                self.css = self.css.slice(idx, 0);
                break;
            } else if (ch0 == ',') {
                // store selector
                var sel = self.css.slice(0, idx);
                const trimed = sel.trim();
                selectorsArr.append(trimed);

                // move to start of next selector
                self.updatePosition(sel);
                self.column += 1; // update position on comma
                // +1 to move past comma
                self.css = self.css.slice(idx + 1, 0);
                idx = 0;
            } else if (ch0 == '/' and self.css.charAt(idx + 1) == '*') {
                // move parser position to start of comment
                self.updatePosition(self.css.slice(0, idx));
                self.css = self.css.slice(idx, 0);

                // parse comment
                try self.skipComments();

                // reset idx
                idx = 0;
            } else {
                idx += 1;
            }
        }

        return selectorsArr;
    }

    fn rule(self: *Parser) ParseError!Rule {
        const startPos = self.position();

        // check that rule has a block
        const braceIdx = self.css.indexOf('{');
        if (braceIdx == -1) {
            return ParseError.ExpectedBlock;
        }

        // create rule ast
        var ruleAST = Rule{
            .selectors = try self.selectors(),
            .declarations = Array(Declaration).alloc(4),
            .parent = null,
            .childRules = Array(Rule).alloc(4),
            .position = PositionRange{
                .start = startPos,
                .end = undefined
            }
        };

        self.skipWhitespace();
        try self.skipComments();

        // skip opening curly brace
        self.css = self.css.slice(1, 0);

        while (self.css.charAt(0) != '}') {
            self.skipWhitespace();
            try self.skipComments();

            var idx: u32 = 0;
            var isDecl = true;
            var isEmpty = false;
            while (idx < self.css.len()) {
                switch (self.css.charAt(idx)) {
                    ':' => {
                        break;
                    },
                    '{' => {
                        isDecl = false;
                        break;
                    },
                    '}' => {
                        isEmpty = true;
                        break;
                    },
                    ';' => {
                        return ParseError.ExpectedColon;
                    },
                    else => {
                        idx += 1;
                    }
                }
            }
            
            if (!isEmpty) {
                if (isDecl) {
                    ruleAST.declarations.append(try self.declaration(idx));
                } else {
                    ruleAST.childRules.append(try self.rule());
                }
            }
        }
        
        // skip closing curly brace
        self.css = self.css.slice(1, 0);
        ruleAST.position.end = self.position();

        // // declarations
        // let decl;
        // while ((decl = declaration())) {
        //     if (decl) {
        //         decls.push(decl);
        //         comments(decls);
        //     }
        // }

        // if (!close()) {
        //     return error("missing '}'");
        // }
        // return decls;

        // try self.declarations(&ruleAST);

        return ruleAST;
    }

    fn rules(self: *Parser) ParseError!Stylesheet {
        var rulesArr = Array(Rule).alloc(2);
        self.comments = Array(Comment).alloc(2);

        while (self.css.len() > 0) {

            self.skipWhitespace();
            try self.skipComments();

            // vexlib.println(self.css);

            if (self.css.len() > 0) {
                if (self.css.charAt(0) == '{') {
                    return ParseError.ExpectedSelector;
                }
                // (node = atrule() or rule())
                const r = try self.rule();
                rulesArr.append(r);
            }

            // vexlib.println("__________");
        }

        return Stylesheet{
            .rules = rulesArr,
            .comments = self.comments
        };
    }

    pub fn parse(self: *Parser, css_: []const u8) ParseError!Stylesheet {
        var buff = Array(u8).using(@constCast(css_));
        buff.len = As.u32(css_.len);
        self.css = String.using(buff);
        return self.rules();
    }

};

pub fn deallocAST(ast_: Stylesheet) void {
    var ast = ast_;

    var i: u32 = 0;
    while (i < ast.rules.len) : (i += 1) {
        var myRule = ast.rules.get(i);
        myRule.selectors.dealloc();
        myRule.declarations.dealloc();
        myRule.childRules.dealloc();
    }

    ast.rules.dealloc();
    ast.comments.dealloc();
}

fn stringifyDeclaration(decl: Declaration) String {
    var out = String.allocFrom(decl.property);
    out.concat(": ");
    out.concat(decl.value);
    out.concat(";");
    return out;
}

fn stringifyRule(rule_: Rule, indentAmt: u32) String {
    var rule = rule_;

    var indentLevel = if (indentAmt == 0) String.allocFrom("    ") else String.allocFrom("        ");
    defer indentLevel.dealloc();

    var out = rule.selectors.join(", ");
    out.concat(" {\n");

    // declarations
    var i: u32 = 0;
    while (i < rule.declarations.len) : (i += 1) {
        var declStr = stringifyDeclaration(rule.declarations.get(i).*);
        defer declStr.dealloc();
        out.concat(indentLevel);
        out.concat(declStr);
        out.concat("\n");
    }

    // sub rules
    i = 0;
    while (i < rule.childRules.len) : (i += 1) {
        var declStr = stringifyRule(rule.childRules.get(i).*, indentAmt + 1);
        defer declStr.dealloc();
        out.concat(indentLevel);
        out.concat(declStr);
        out.concat("\n");
    }
    if (indentAmt != 0) {
        out.concat(indentLevel.slice(0, 4));
    }
    out.concat("}");

    return out;
}

pub fn stringify(stylesheet: Stylesheet) String {
    var out = String.alloc(256);
    var rules = stylesheet.rules;
    var i: u32 = 0;
    while (i < rules.len) : (i += 1) {
        var ruleStr = stringifyRule(rules.get(i).*, 0);
        defer ruleStr.dealloc();
        out.concat(ruleStr);
        out.concat("\n\n");
    }
    return out;
}