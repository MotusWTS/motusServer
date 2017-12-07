// javascript for calling the status API and building DOM objects from results
// custom javascript to access the API directly from the browser / client
// Assumes jquery has already been loaded.

// assume there's an authTicket available in the auth_tkt cookie:


// where to send API requests
var serverURL = "https://sgdata.motus.org/status2/";

// state of page
var state = {
    authToken : decodeURIComponent(document.cookie.match(/(^|;)auth_tkt=([^;]*)(;|$)/)[2]),
    // selectors
    selector : {},
    // ordering
    sortBy :"mtime",
    sortDesc: true,
    lastKey : [],
    forwardFromKey: true,
    // other
    debug: false // show dialog when query runs
};

var latest_job_list = null;

// @function toArray: guarantee argument is an array
//
// @param x: scalar, array, or object
// @return x as an array; if x is already an array, just return it.
// If `x` is a scalar, wrap it into an array with one element.
// If 'x' is an object, return its values, in the order indexed by Object.keys(x)

toArray = function(x) {
    if (Array.isArray(x))
        return x;
    if (typeof(x) == "object")
        return Object.keys(x).map((i)=>x[i]);
    return [x];
};

// @method Array.last
// @return last element of array
if (!Array.prototype.last) {
    Array.prototype.last = function() {
        return this[this.length - 1];
    };
};

// @function motus_status_api: call one of the motus status API entries
//
// @param api: entry, e.g. "authenticate_user", "status_api_info", "list_jobs", "subjobs_for_job", ...
// @param par: javascript object, passed as the POST parameter 'json'
// @param cb: callback; a function accepting a javascript object which is the return from the API
//
// @return nothing

function motus_status_api(api, par, cb) {
    if (api != "authenticate_user") {
        par.authToken = state.authToken;
    }
    if (state.debug) {
        $(".querying_server").mustache("tpl_querying_server",
                                       {
                                           query: api,
                                           params: JSON.stringify(par, omit_authToken, 3)
                                       },
                                       {
                                           method:"html"
                                       }
                                      );

        $(".querying_server").dialog(
            {
                top: $("html").offset().top,
                maxHeight: 800,
                dragable:false,
                closeOnEscape:true,
                width:800,
                title:"Querying motus status server"
            });
        $(".querying_server_message").addClass("querying_server_active")
    }
    $.post(serverURL + api, {"json":JSON.stringify(par)}, function(x) {motus_status_replied(x, api, par, cb)});
};

// @function omit_authToken: remove the authToken from a JSON-serialization of an object
// @param key: name of item
// @param val: value of item
//
// This function is used as the `replacer` argument in a call to JSON.stringify().

function omit_authToken (key, val) {
    return key == "authToken" ? "(omitted)" : val;
};

// @function motus_status_replied: handle the return from a motus status API call
//
// @param x: object returned by API
//
// The remaining parameters are the parameters specified in the call to motus_status_api():
// @param api: api called
// @param par: object, passed as the POST parameter 'json'
// @param cb: callback specified by user
//
// @return nothing
function motus_status_replied(x, api, par, cb) {
    if (state.debug)
        $(".querying_server_message").removeClass("querying_server_active").addClass("querying_server_done");
    if (x.error) {
        $(".job_error").mustache("tpl_job_error",
                                 {
                                     error:x.error,
                                     api: serverURL + api,
                                     state: JSON.stringify(state, omit_authToken, 3),
                                     json: JSON.stringify(par, omit_authToken, 3)
                                 },
                                 {
                                     method:"html"
                                 }
                                );
        $(".job_error").dialog(
            {
                top: $("html").offset().top,
                maxHeight: 800,
                dragable:false,
                closeOnEscape:true,
                width:800,
                title:"Error from Motus Status Server!"
            });
        $(".copy_error_message").button({icon:"ui-icon-copy"}).on("click", function() {copyToClipboard(".job_error_contents")});
        return;
    }
    if (api == "authenticate_user") {
        state.authToken = x.authToken;
        return;
    }
    if (! (x.id && x.id.length)) {
        $(".job_no_results").mustache("tpl_job_no_results", {}, {method:"html"});
        $(".job_no_results").dialog(
            {
                top: $("html").offset().top,
                maxHeight: 300,
                dragable:true,
                closeOnEscape:true,
                width:300,
                title:"No jobs found!"
            });
        return;
    }
    cb(x);
};

// @function show_job_list: display a list of jobs
//
// @param sortBy; sort order; default: "mtime"
// @param lastKey: last key for given sort order; default: null
//
// @details construct query according to search criteria, fetch
// summary list of jobs, then chains to show_job_list2

function show_job_list() {
    var pars = {
        options:{
            includeUnknownProjects:true,
            full:true
        },
        order:{
            sortBy: state.sortBy + (state.sortDesc ?" desc" : ""),
            lastKey: state.lastKey,
            forwardFromKey: state.forwardFromKey
        }
    };
    if (state.selector.motusUserID) {
        pars.select = {userID: state.selector.motusUserID}
    } else if (state.selector.motusProjectID) {
        pars.select = {projectID: state.selector.motusProjectID}
        pars.options.includeUnknownProjects = false;
    } else if (state.selector.id) {
        pars.select = {jobID: state.selector.id}
        pars.order.sortBy = "id";
    } else if (state.selector.idnear) {
        pars.order.sortBy = "id";
        pars.order.lastKey = [state.selector.idnear - 10];
        pars.order.sortDesc = false;
        pars.order.forwardFromKey = true;
    } else if (state.selector.type) {
        pars.select = {type: state.selector.type};
    } else if (state.selector.log) {
        // add globbing wildcards to match anywhere in log
        pars.select = {log: "*" + state.selector.log + "*"};
    }
    if (state.maxRows) {
        pars.options.maxRows = state.maxRows;
    }
    motus_status_api("list_jobs", pars, show_job_list2);
};

// @function show_job_list2: display the summary list of jobs
//
// @param x: summary list of jobs
//
// @details receive details for jobs and display them in main div

function show_job_list2(x) {
    x.__transpose__ = true;

    if (x.id.length == 0) {
        if (latest_job_list)
            return;
    }
    latest_job_list = x;
    if ($(".job_details").dialog('instance'))
        $(".job_details").dialog('close');
    $(".job_list").mustache("tpl_job_list",
                            {
                                jobs:x,
                                params:function(i) {
                                    return fmt_params(this.data[i])
                                },
                                fmt_ctime:function(i) {
                                    return fmt_time(this.ctime[i])
                                },
                                fmt_mtime:function(i) {
                                    return fmt_time(this.mtime[i])
                                },
                                fmt_done:function(i) {
                                    return fmt_done(this.sjDone[i], this.queue[i])
                                }
                            },
                            {
                                method:"html"
                            }
                           );
    // style the sort-order buttons
    $(".sort_heading").button({icon:"ui-icon-blank"});

    // add an appropriate icon to the column header by which we sorted
    var sorter = $('.sort_heading[sort_field="' + state.sortBy + '"]');
    sorter.button({icon: "ui-icon-triangle-1-" + (state.sortDesc ? "s" : "n"), minHeight:200});
    // add navigation buttons
    $(".navigate").button();
    $('.navigate[target="top"]').button({icon:"ui-icon-arrowthickstop-1-w"});
    $('.navigate[target="bottom"]').button({icon:"ui-icon-arrowthickstop-1-e"});
    $('.navigate[target="up"]').button({icon:"ui-icon-arrowthick-1-w"});
    $('.navigate[target="down"]').button({icon:"ui-icon-arrowthick-1-e"});

};

// @function show_job_details: display a pop-up with details of a job and its subjobs
//
// @param jobID: motus job ID
//
// @details fetch detailed list of subjobs, then chain to show_job_details2

function show_job_details(jobID) {
    motus_status_api("list_jobs",
                     {
                         select:{
                             stump: jobID
                         },
                         options:{
                             includeUnknownProjects:true,
                             full:true,
                             includeSubjobs:true
                         },
                         order:{
                             sortBy:"id"
                         }
                     }, show_job_details2);
};

function fmt_time(x) {
    return (new Date(1000 * x)).toISOString();
};

function fmt_params(x) {
    x = JSON.parse(x);
    if (x == null) {
        return "";
    }
    return Object.keys(x).filter(k=>k[k.length-1] != '_').map(k=>k +" = " + x[k]).join("; ");
};

// @function fmt_done: format a status code
// @param status: integer status code: < 0 means error, 0 means not run, 1 means run successfully
// @param queue: integer queue number: non-zero means has entered (and possibly finished) that queue

function fmt_done(status, queue) {
    switch (status) {
    case 0:
        if (! queue || ! (queue > 0))
            return '<span class="status_waiting">Waiting</span>';
        else
            return '<span class="status_running">Running on Queue # ' + Math.round(queue) + '</span>';
        break;
    case 1:
        return '<span class="status_okay">Okay</span>';
        break;
    default:
        return '<span class="status_error">Error</span>';
        break;
    }
};

// @function show_job_details2: display a pop-up div with details of a job and its subjobs
//
// @param x: detailed list of subjobs for a job (including the job itself), as
// returned by the reply to the motus status API entry `list_jobs`
//
// @details receive details for subjobs and display them in a popup div

function show_job_details2(x) {
    x.__transpose__ = true;
    json = x.data.map(JSON.parse);

    // Currently we're using auto_unbox = TRUE in toJSON() when storing
    // job properties in the `data` column of the server's jobs
    // database.  Unfortunately, this means vectors of length 1 are
    // JSON-encoded as scalars, instead of arrays.  This is a problem
    // for fields such as `products_` which should always be an array, even if
    // of length 1.  For now,t he workaround is to wrap fields which *should be*
    // arrays in the `toArray()` function defined above.

    // Note that this doesn't apply to columns returned by the API, which are
    // always arrays.

    $(".job_details").mustache("tpl_job_details",
                               {
                                   details:x,
                                   log:json[0].log_,
                                   summary:json[0].summary_,
                                   fmt_ctime:function(i) {
                                       return fmt_time(this.ctime[i])
                                   },
                                   params:function(i) {
                                       return fmt_params(this.data[i])
                                   },
                                   fmt_done:function(i) {
                                       return fmt_done(this.done[i], this.queue[i])
                                   },
                                   products: json[0].products_ && json[0] ? {
                                       __transpose__: true,
                                       link: toArray(json[0].products_),
                                       name: toArray(json[0].products_).map(i=>String.replace(i, /^.*\//, ""))
                                   } : null
                               },
                               {
                                   method:"html"
                               }
                              );

    var rowid = '#jobs_table_row' + x.id[0];
    $(".jobs_table_row").removeClass("highlighted_jobs_table_row");
    $(rowid).addClass("highlighted_jobs_table_row");
    $(".job_details").dialog(
        {
            top: $("html").offset().top,
            maxHeight: 600,
            dragable:false,
            closeOnEscape:true,
            width:800,
            title:"Details for top-level job " + x.id[0]
        }).on(
            "dialogclose",
            function(){$(rowid).removeClass("highlighted_jobs_table_row")}
        );
};

function on_click_jobs_table_row(event) {
    // extract the job_id from the "currentTarget" of the event; that will be
    // the jobs table row, as chosen by the dynamic selector in the .on("click", ...) call
    // which registered this handler.

    // don't handle event if this is a selection
    if (window.getSelection().toString().length == 0)
        show_job_details(event.currentTarget.getAttribute("job_id"));
};

function on_click_sort_heading(event) {
    // extract the sort_field from the "currentTarget" of the event
    var oldSortBy = state.sortBy;
    state.sortBy = event.currentTarget.getAttribute("sort_field");
    if (oldSortBy == state.sortBy) {
        state.sortDesc =! state.sortDesc;
    } else {
        state.lastKey = [latest_job_list[state.sortBy][0]];
        state.forwardFromKey = true;
        state.sortDesc = false;
    }
    show_job_list();
};

function on_click_navigate(event) {
    // extract the navigation target from the "currentTarget" of the event
    var target = event.currentTarget.getAttribute("target");
    switch(target) {
    case "top":
        state.lastKey = [];
        state.forwardFromKey = true;
        break;
    case "bottom":
        state.lastKey = [];
        state.forwardFromKey = false;
        break;
    case "up":
        state.lastKey = [latest_job_list[state.sortBy][0]];
        if (state.sortBy != "id")
            state.lastKey.push(latest_job_list.id[0]);
        state.forwardFromKey = false;
        break;
    case "down":
        state.lastKey = [latest_job_list[state.sortBy].last()];
        if (state.sortBy != "id")
            state.lastKey.push(latest_job_list.id.last());
        state.forwardFromKey = true;
        break;
    };
    show_job_list();
};

function on_click_search(event) {
    var findVal = $("#find_job_key").val();
    switch($("#find_job_selector").val()) {
    case "id":
        state.selector = {id: parseInt(findVal)};
        break;
    case "idnear":
        state.selector = {idnear: parseInt(findVal)};
        break;
    case "motusUserID":
        state.selector = {motusUserID: findVal};
        break;
    case "motusProjectID":
        state.selector = {motusProjectID: findVal};
        break;
    case "log":
        state.selector = {log: findVal};
        break;
    case "all":
        state.selector = {};
        break;
    }
    show_job_list();
};

function on_keyup_find_job_key(evt) {
    if (evt.keyCode==13)
        $("#find_job_button").click();
};

function on_change_find_job_selector(evt) {
    var vis;
    switch($("#find_job_selector").val()) {
    case "all":
        vis = false
        break;
    default:
        vis = true;
        break;
    };
    $("#find_job_key").toggle(vis);
    $("#find_job_button").toggle(vis);

    // we've switched to the "all" jobs view, which has no other
    // controls, so (re)load the list
    if (!vis) {
        state.selector = {};
        show_job_list();
    }
};

function initStatus2Page() {
    $.Mustache.addFromDom();
    // attach a click handler to rows in the job table
    // Because they haven't been created yet, we need an existing static selector (".job_list")
    // on which to hang the handler, which then delegates the events to the appropriate element
    // chosen by the dynamic selector (".jobs_table_row")
    $(".job_list").on("click", ".jobs_table_row", on_click_jobs_table_row);

    // attach a click handler to column headings.
    $(".job_list").on("click", ".sort_heading", on_click_sort_heading);

    // attach a click handler to navigation buttons.
    $(".jobs_navigation").on("click", ".navigate", on_click_navigate);

    // attach a click handler to the find_jobs_selector
    $("#find_job_selector").selectmenu();
    $("#find_job_selector").on("selectmenuchange", on_change_find_job_selector);
    $("#find_job_selector").val("all").selectmenu("refresh");
    on_change_find_job_selector();
    $("#find_job_key").on("keyup", on_keyup_find_job_key);
    $('#find_job_button').button({icon:"ui-icon-search", }).on("click", on_click_search);
};

// @function copyToClipboard: copy the text from an element to the client's clipboard
// @param element: jquery element selector
//
// source: Alvaro Montaro via https://stackoverflow.com/a/30905277

function copyToClipboard(element) {
    var $temp = $("<textarea>");
    $("body").append($temp);
    $temp.val($(element).text()).select();
    document.execCommand("copy");
    $temp.remove();
}
