// simple templating: replace all escaped substrings with their
// evaluation in a context.
//
// @param s: a string
//
// @param c: a context; this is an object with named fields.  The
// names of the fields are added to the start of the search list for
// symbols when the template is filled in by evaluation of its quoted
// substrings.  These names can then appear in escaped
// substrings, where they will be replaced by their value in `c`.
//
// @param E, F: opening/closing escape characters; a substring in `s`
// that begins with the first character of E and ends with the first
// character of F and does not include either character is replaced
// with its evaluation (without leading E and trailing F) in the
// context `c`.  E defaults to '@', and F defaults to E.  An escaped
// empty string (i.e. the character in E immediately followed by the
// character in F) gets replaced by the character in E.
//
// To increase visual emphasis of escaped substrings, you can dip into
// unicode, e.g.  use E="⸨" and F="⸩"
//
// A simple attempt to escape double quotes in escaped substrings is made,
// but you should try to avoid them as they can break the call to eval.
//
// The function uses one call to `eval` (using `with`), and two calls to `String.replace`
// with a function as second parameter.
//
// @author John Brzustowski \email{jbrzusto@@REMOVE_THIS_PART_fastmail.fm}

tplate = function(s, c, E, F) {
    var e = [];
    c = c || {};
    E = E ? E[0] : '@';
    F = F ? F[0] : E;
    var r = RegExp(E + '([^' + E + F + ']*)' + F, "g");
    s.replace(r, function(m, x) {e.push(x.replace(/([^\\])"/g, '$1\\"') || '"' + E  + '"')});
    e = eval('with(c){[' + e.join(",") + ']}');
    var i=0;
    s = s.replace(r, function(m, x) {return(e[i++]);});
    return(s);
}
