// based on custom-ui example from shiny gallery

(function() {

function updateMatcher(matcher) {
    matcher = $(matcher);
    // var left = matcher.find("select.left");
    // var right = matcher.find("select.right");
    // var leftArrow = matcher.find(".left-arrow");
    // var rightArrow = matcher.find(".right-arrow");
    
    // var canMoveTo = (left.val() || []).length > 0;
    // var canMoveFrom = (right.val() || []).length > 0;
    
    // leftArrow.toggleClass("muted", !canMoveFrom);
    // rightArrow.toggleClass("muted", !canMoveTo);
}

function eq(n) { return(":eq(" + n + ")");}

function swap(matcher, source, i, j) {
    // swap children selected by i and j
    matcher = $(matcher);
    var ei = matcher.find(source).children(i);
    var ej = matcher.find(source).children(j);
    ii = ei.index()
    jj = ej.index()
    if (ii == jj) {
        return
    } else if (ii < jj) {
        et = ei.next()
        ei.insertAfter(ej)
        ej.insertBefore(et)
    } else {
        et = ej.next()
        ej.insertAfter(ei)
        ei.insertBefore(et)
    }
    updateMatcher(matcher);
    matcher.trigger("change");
}

$(document).on("change", ".matcher select", function() {
//    updateMatcher($(this).parents(".matcher"));
});

$(document).on("dblclick", ".matcher-left-option", function() {
    swap($(this).parents(".matcher"), ".right", ":selected", eq($(this).index()))
});

$(document).on("dblclick", ".matcher-right-option", function() {
    swap($(this).parents(".matcher"), ".right", eq($(this).parents(".matcher").find(".left").children(":selected").index()), eq($(this).index()))
});

$(document).on("click", ".matcher-ok", function() {
});

$(document).on("click", ".matcher-cancel", function() {
});

var binding = new Shiny.InputBinding();

binding.find = function(scope) {
  return $(scope).find(".matcher");
};

binding.initialize = function(el) {
  updateMatcher(el);
};

binding.getValue = function(el) {
  return  {"blam":$.makeArray($(el).find("select.right option").map(function(i, e) { return $(e).attr("listInd"); }))}
};

binding.setValue = function(el, value) {
  // TODO: implement
};

binding.subscribe = function(el, callback) {
  $(el).on("change.matcherBinding", function(e) {
    callback();
  });
};

binding.unsubscribe = function(el) {
  $(el).off(".matcherBinding");
};

binding.getType = function() {
  return "matcher";
};

Shiny.inputBindings.register(binding, "matcher");

})();
