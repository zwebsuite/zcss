const parse = require("css-tree").parse;

var ast = parse(`
    .parent-rule {
        /* parent rule properties */
        .child-rule {
            /* child rule properties */
        }
    }
`, { source: 'source.css' });


console.log(JSON.stringify(ast, "", "    "))