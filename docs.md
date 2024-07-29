# Documentation

## Exports

### Parser
```rs
struct Parser {
    fn parse(cssCode: []const u8) ParseError!Stylesheet;
}
```
#### Example Usage
```ts
const zcss = @import("zcss");
const cssFile = "body { margin: 0px; }";
var myParser = zcss.CSSParser{};
const ast = try myParser.parse(cssFile);
```

### ParseError
```rs
error {
    ExpectedEndOfComment,
    ExpectedSelector,
    ExpectedBlock,
    ExpectedColon,
    ExpectedDeclaration
}
```

### Stylesheet
```rs
struct Position {
    line: u32,
    column: u32
}

struct PositionRange {
    start: Position,
    end: Position
}

struct Declaration {
    property: String,
    value: String,
    position: PositionRange
}

struct Rule {
    selectors: Array(String),
    declarations: Array(Declaration),
    parent: ?*Rule,
    childRules: Array(Rule),
    position: PositionRange,
}

struct Comment {
    value: String,
    position: PositionRange,
}

struct Stylesheet {
    rules: Array(Rule),
    comments: Array(Comment)
}
```

### stringify
```rs
fn stringify(stylesheet: Stylesheet) String;
```

#### Example Usage
```ts
const ast = try myParser.parse(cssFile);
try expect(zcss.stringify(ast).equals(cssFile));
```
