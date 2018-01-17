// Code to access the status API directly from the browser / client.
// Assumes jquery has already been loaded.

// where to send API requests
var serverURL = "https://sgdata.motus.org/status2/";

// state of page
var state;

// placeholder for parsed query parameters
var initial_query;

var latest_job_list = null; // list of jobs from most recent successful query

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
                dragable:true,
                closeOnEscape:true,
                width:800,
                title:"Querying motus status server"
            });
        $(".querying_server_message").addClass("querying_server_active")
    } else {
        // set a timer to display a progress bar if the query hasn't
        // completed quickly (under 1.5 seconds)
        state.progress_timeout = setTimeout(show_query_progress, 1500);
    };
    $.post(serverURL + api, {"json":JSON.stringify(par)}).done(motus_status_replied).fail(motus_query_failed)._extra =
        {
            api: api,
            pars: par,
            cb: cb
        };
};

// @function show_query_progress:  show an indeterminate progress bar for a query that takes more than a second
// or two

function show_query_progress() {
    $(".query_progress_bar").mustache("tpl_query_progress_bar", {}, {method:"html"});
    $(".query_progress_bar_widget").progressbar({value:false});
    $(".query_progress_bar").dialog(
        {
            top: $("html").offset().top,
            maxHeight: 800,
            dragable:true,
            closeOnEscape:true,
            width:300,
            title:"Querying motus status server"
        });
    state.have_progress_dialog = true;
};

// @function omit_authToken: remove the authToken from a JSON-serialization of an object
// so we can display contents of an API call without auth cruft
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
// The remaining parameters are those specified in the call to motus_status_api():
//
// @param api: api called
// @param par: object, passed as the POST parameter 'json'
// @param cb: callback specified by user
//
// @return nothing
function motus_status_replied(x, textStatus, jqXHR) {
    if (state.debug) {
        $(".querying_server_message").removeClass("querying_server_active").addClass("querying_server_done");
    } else {
        if (state.progress_timeout) {
            clearTimeout(state.progress_timeout);
            if (state.have_progress_dialog) {
                $(".query_progress_bar").dialog("close");
                state.have_progress_dialog = false;
            }
            state.progress_timeout = null;
        }
    };
    cb = jqXHR._extra.cb;
    api = jqXHR._extra.api;
    if (x.error) {
        par = jqXHR._extra.par;
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
                dragable:true,
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
    if (api == "list_jobs" && ! (x.id && x.id.length)) {
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
    if (typeof cb === "function")
        cb(x);
};

// @function motus_query_failed: handle a query that didn't process successfully
//
// @param jqXHR the request object
// @textStatus an error message
// @errorThrown more details on error
//
// @return nothing
function motus_query_failed(jqXHR, textStatus, errorThrown) {
    if (state.debug) {
        $(".querying_server_message").removeClass("querying_server_active").addClass("querying_server_done");
    } else {
        if (state.progress_timeout) {
            clearTimeout(state.progress_timeout);
            if (state.have_progress_dialog) {
                $(".query_progress_bar").dialog("close");
                state.have_progress_dialog = false;
            }
            state.progress_timeout = null;
        }
    };
    $(".job_error").mustache("tpl_job_error",
                             {
                                 error:textStatus + "\n" + jqXHR.responseText,
                                 api: jqXHR._extra.URL,
                                 state: JSON.stringify(state, omit_authToken, 3),
                                 json: JSON.stringify(jqXHR._extra.pars, omit_authToken, 3)
                             },
                             {
                                 method:"html"
                             }
                            );
    $(".job_error").dialog(
        {
            top: $("html").offset().top,
            maxHeight: 800,
            dragable:true,
            closeOnEscape:true,
            width:800,
            title:"Error querying Motus Status Server!"
        });
    $(".copy_error_message").button({icon:"ui-icon-copy"}).on("click", function() {copyToClipboard(".job_error_contents")});
    return;
};

// @function linkify_sernos: for each receiver serial number found in a string,
// enclose it in a span of class "receiver_serno" with attribute "serno" equal
// to the receiver serial number.
//
// @param s: string
// @return s with any serial numbers linkified
// @note: the _JSON variants use escaped quotes

var serno_re=/(?:(?:(?:SG-[0-9A-Z]{4}(?:RPi[123z]|BBBK|(?:BB[0-9][0-9A-Z]))[0-9A-Z]{4}(?:_[0-9])?))|(?:Lotek-D?[0-9]+))|(?:-[0-9A-Z]{4}(?:RPi[123z]|BBBK|(?:BB[0-9][0-9A-Z]))[0-9A-Z]{4}-)/ig;

function linkify_one_serno(match) {
    return '<span class="receiver_serno" serno="' + match + '">' + match + '</span>';
};

function linkify_sernos(s) {
    return s.replace(serno_re, linkify_one_serno);
};

function linkify_one_serno_JSON(match) {
    return '<span class=\\"receiver_serno\\" serno=\\\"' + match + '\\">' + match + '</span>';
};

function linkify_sernos_JSON(s) {
    return s.replace(serno_re, linkify_one_serno_JSON);
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
            full:true,
            errorOnly:state.errorOnly
        },
        order:{
            sortBy: state.sortBy,
            sortDesc: state.sortDesc,
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
                                    return fmt_time(this.ctime[i], 16)
                                },
                                fmt_mtime:function(i) {
                                    return fmt_time(this.mtime[i], 19)
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
    $(".sort_heading").button();

    // add an appropriate arrow to the column header by which we sorted
    // Note: doing this with icons leads to buttons with varying height
    var sorter = $('.sort_heading[sort_field="' + state.sortBy + '"]')[0];
    // Use a non-breaking space between the arrow and heading
    sorter.innerText = sorter.innerText + "\u00a0" + "↑↓".substr(state.sortDesc, 1);
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

function fmt_filesize(n) {
    if (n >= 1e9)
        return Math.round(n / 1e8) / 10 + " GB";
    if (n >= 1e6)
        return Math.round(n / 1e5) / 10 + " MB";
    if (n >= 1e3)
        return Math.round(n / 1e2) / 10 + " kB";
    return n + " Bytes";
};

function fmt_time(x, n) {
    if ((!x) || x == "NA") {
        rv = "NA";
    } else {
        rv = (new Date(1000 * x)).toISOString();
        if (n !== undefined)
            rv = rv.substring(0, n);
    }
    return rv.replace(/T/, "\u00A0");
};

function fmt_params(x, with_links=false) {
    if (x === null)
        return "";
    if (with_links)
        x = linkify_sernos_JSON(x);
    x = JSON.parse(x);
    rv = Object.keys(x).filter(k=>k[k.length-1] != '_').map(k=>k +" = " + x[k]).join("; ");
    return rv.replace(/filename = \/.*\/[0-9]+_[^_]+_/, "filename = ");
};

// @function user_type
// return user type from authToken, or "" if none available

function user_type() {
    if (state.authToken !== undefined)
        return state.authToken.split(/!/)[2];
    return "";
};

// @function fmt_done: format a status code
// @param status: integer status code: < 0 means error, 0 means not run, 1 means run successfully
// @param queue: integer queue number: non-zero means has entered (and possibly finished) that queue
// @param jobID: integer job ID; used to generate links to stack dumps, if user is administrator

function fmt_done(status, queue, jobID) {
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
        if (jobID === undefined || user_type() != "administrator") {
            return '<span class="status_error">Error</span>';
        } else {
            return '<span class="status_error error_job_id" job_id="' + jobID + '">Error</span>';
        }
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
                                   hasLog:function(i) {return json[i] && json[i].log_},
                                   logs: {
                                       __transpose__: true,
                                       msg: json.map(val=>(val && val.log_) ? linkify_sernos(val.log_) : null),
                                       jobID: x.id
                                   },
                                   summary:linkify_sernos(json[0].summary_),
                                   fmt_ctime:function(i) {
                                       return fmt_time(this.ctime[i])
                                   },
                                   params:function(i) {
                                       return fmt_params(this.data[i], true)
                                   },
                                   fmt_done:function(i) {
                                       return fmt_done(this.done[i], this.queue[i], this.id[i])
                                   },
                                   products: json[0].products_ && json[0] ? {
                                       __transpose__: true,
                                       link: toArray(json[0].products_),
                                       name: toArray(json[0].products_).map(i=>i.replace(/^.*\//, ""))
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
            dragable:true,
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

function on_click_receiver_serno(event) {
    // extract the serno from the "currentTarget" of the event
    // then show info for that receiver

    // don't handle event if this is a selection
    if (window.getSelection().toString().length == 0) {
        var serno = event.currentTarget.getAttribute("serno");
        // serial numbers for SGs can look like /-[0-9A-Z]{4}...-/ if
        // they come from a receiver filename; convert those
        // to standard ones
        if (serno[0] == "-")
            serno = "SG" + serno.slice(0, -1);
        show_recv_info(serno);
    }
};

function on_click_recv_file_day_count(event) {
    // extract the serno and day from the "currentTarget" of the event
    // then show files for that receiver and day

    // don't handle event if this is a selection
    if (window.getSelection().toString().length == 0)
        show_recv_files(event.currentTarget.getAttribute("serno"), event.currentTarget.getAttribute("day"));
};

function on_click_error_job_id(event) {
    // extract the job id from the "currentTarget" of the event
    // then show an error dump download dialog

    // don't handle event if this is a selection
    if (window.getSelection().toString().length == 0)
        show_error_dump(event.currentTarget.getAttribute("job_id"));
};

function on_click_subjob_id(event) {
    // extract the job id from the "currentTarget" of the event
    // then jump to log for that job ID

    // don't handle event if this is a selection
    if (window.getSelection().toString().length == 0) {
        var jobID = event.currentTarget.getAttribute("job_id");
        $(".job_details").scrollTop($(".job_details").scrollTop() + $(".subjob_log_heading[job_id='" + jobID + "']").offset().top - $(".job_details").offset().top);
    }
};

function on_click_subjob_log_heading(event) {
    // extract the job id from the "currentTarget" of the event
    // then jump to subjob_table_row for that job ID

    // don't handle event if this is a selection
    if (window.getSelection().toString().length == 0) {
        var jobID = event.currentTarget.getAttribute("job_id");
        $(".job_details").scrollTop($(".job_details").scrollTop() + $(".subjob_id[job_id='" + jobID + "']").offset().top - $(".job_details").offset().top);
    }
};


function on_click_sort_heading(event) {
    // extract the sort_field from the "currentTarget" of the event
    var oldSortBy = state.sortBy;
    state.sortBy = event.currentTarget.getAttribute("sort_field");
    if (oldSortBy == state.sortBy) {
        state.sortDesc =! state.sortDesc;
    } else {
        state.lastKey = null;
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

function on_error_only(event) {
    state.errorOnly = $("#error_only_option").is(":checked");
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
    $("#find_job_key_span").toggle(vis);
    $("#find_job_button").toggle(vis);

    // we've switched to a jobs view that has no other controls, so
    // (re)load the list
    if (!vis) {
        state.selector = {};
        show_job_list();
    }
};

function on_click_retry_job(event) {
    var message = $("#retry_job_message").val();
    var jobID = event.currentTarget.getAttribute("job_id");
    $("#retry_job_button").button("disable");
    retry_job(jobID, message);
};

function getAuthTicketFromCookie() {
    if (! document.cookie)
        return null;
    var parts = document.cookie.match(/(^|;\s*)auth_tkt=([^;]*)(;|$)/);
    if (parts && parts.length > 2)
        return decodeURIComponent(parts[2]);
    return null;
};

function initStatus2Page() {
    state = {
        // assume there's an authTicket available in the auth_tkt cookie:
        authToken : getAuthTicketFromCookie(),
        // selectors choose which jobs are shown
        selector : {},
        // ordering chooses what order to show available jobs
        sortBy :"mtime",
        sortDesc: true,
        // should only jobs with (subjobs having) errors be shown?
        errorOnly: false,
        lastKey : [],
        forwardFromKey: true, // when paging up/down; we specify first/last key, and direction from it
        // other
        debug: false // show dialog when query runs
    };

    // in case a json QUERY parameter was supplied to the URL, use it as state instead.

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
    $('#find_job_key_span').addClass("ui-widget ui-widget-content ui-corner-all");
    $("#find_job_key").on("keyup", on_keyup_find_job_key);
    $('#find_job_button').button({icon:"ui-icon-search", }).on("click", on_click_search);

    // attach a click handler to the error_only_option checkbox
    $("#error_only_option").checkboxradio().on("click", on_error_only);

    // attach a click handler to any field with class job_id that's in a recv_files section
    $(".recv_info").on("click", ".recv_file_day_count", on_click_recv_file_day_count);

    // attach a click handler to any field with class job_id that's in a recv_files section
    $(".recv_files").on("click", ".job_id", on_click_jobs_table_row);

    // attach a click handler to any field with class receiver_serno that's in a job_details section
    $(".job_details").on("click", ".receiver_serno", on_click_receiver_serno);

    // attach a click handler to any error_job_id field, indicating a stack dump exists
    $(".job_details").on("click", ".error_job_id", on_click_error_job_id);

    // attach a click handler to IDs of subjobs in detailed job listing
    // which take user to the log for that subjob
    $(".job_details").on("click", ".subjob_id", on_click_subjob_id);

    // attach a click handler to headings of subjobs in log
    // which take user to the subjob entry
    $(".job_details").on("click", ".subjob_log_heading", on_click_subjob_log_heading);

    // read the state of the checkbox, which might be preserved across reloads
    state.errorOnly = $("#error_only_option").is(":checked");

    // set the global query parameter getter, based on the initial page URL
    // this can be used like so:
    // json = initial_query.get('json')
    initial_query = new URLSearchParams(location.search.slice(1));

    // determine which API call to make from any query parameters provided.
    handle_initial_query(initial_query);
};

// @function handle_initial_query deal with user-specified GET parameters
// and call the appropriate page-populating function
//
// @param query
//
// So far, we support these:
//  -  (no query parameters):  list the most recently-active jobs
//  -  jobID=N:  show the single-line status for the specified job
//  -  serno=XXX: show the receiver summary page for XXX, which should be
//     a receiver serial number, e.g. "SG-1234BBBK5678" or "Lotek-158"

function handle_initial_query(query) {

    // what type of query was specified?
    var type = "";

    // determine the query type and its parameters
    if (jobID = query.get("jobID")) {
        type = "jobID";
    } else if (serno = query.get("serno")) {
        type = "serno";
    }

    switch(type) {
    case "jobID":
        $("#find_job_selector").val("id").selectmenu("refresh");
        $("#find_job_key").val(jobID);
        state.selector = {id: jobID};
        // simulate a click so that the appropriate form controls are visible
        on_change_find_job_selector();

        show_job_list();
        break;
    case "serno":
        show_recv_info(serno);
        break;
    default:
        show_job_list();
    }
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
};

// @function show_recv_info: display a pop-up with info about a receiver
//
// @param serno: receiver serial number
//
// @details fetch receiver info, then chain to show_recv_info2

function show_recv_info(serno) {
    motus_status_api("get_receiver_info",
                     {
                         serno: serno
                     }, show_recv_info2);
};

// @function show_recv_info2: partially populate receiver info div, then
// grab file summary from API.
//
// @param x: receiver info, as returned by the motus status API entry
// `get_receiver_info`
//
// @details fetch file summary, then chain to show_recv_info3

var globalRecvInfo = {};

function show_recv_info2(x) {
    globalRecvInfo[x.serno] = x;
    motus_status_api("list_receiver_files",
                     {
                         serno: x.serno
                     }, show_recv_info3);
};

// @function show_recv_info3: display a pop-up div with receiver information
//
// @param x: daily file summary, as returned by the motus status API entry
// `list_receiver_files` with `day=null`


function show_recv_info3(x) {
    if (x.fileCounts)
        x.fileCounts.__transpose__ = true;
    var serno = x.serno;
    var gri = globalRecvInfo[serno];
    gri.deployments.__transpose__ = true;

    $(".recv_info").mustache("tpl_recv_info",
                             {
                                 serno: x.serno,
                                 deviceID: gri.deviceID,
                                 receiverType: gri.receiverType,
                                 deployments: gri.deployments,
                                 fmt_tsStart: function(i) {
                                     return fmt_time(this.tsStart[i], 16)
                                 },
                                 fmt_tsEnd: function(i) {
                                     return fmt_time(this.tsEnd[i], 16)
                                 },
                                 fileCountStatus: function(i) {
                                     return this.countFS[i] === this.countDB[i] ? "" : "filecount_mismatch";
                                 },
                                 fmt_fileCount: function(i) {
                                     return this.day[i] + ':' +
                                         ((this.countFS[i] === this.countDB[i]) ?
                                          ('         ' + this.countFS[i]).slice(-9)
                                          : ('         ' + this.countFS[i] + '/' + this.countDB[i]).slice(-9))
                                         + '   ';
                                 },
                                 fileCounts: x.fileCounts
                             },
                             {
                                 method:"html"
                             }
                            );
    $(".recv_info").dialog(
        {
            top: $("html").offset().top,
            maxHeight: 600,
            dragable:true,
            closeOnEscape:true,
            width:900,
            title:"Information for receiver " + serno
        });
};

// @function show_recv_files: display a pop-up with info about receiver files
//
// @param serno: string; receiver serial number
// @param day: string; day, formatted as "YYYY-MM-DD"
//
// @details fetch file details, then chain to show_recv_files2

function show_recv_files(serno, day) {
    motus_status_api("list_receiver_files",
                     {
                         serno: serno,
                         day: day
                     }, show_recv_files2);
};

// @function show_recv_files2: display a pop-up with info about receiver files
//
// @param x: daily file summary, as returned by the motus status API entry
// `list_receiver_files` with `day` a valid "YYYY-MM-DD"


function show_recv_files2(x) {
    x.fileDetails.__transpose__ = true;
    var serno = x.serno;

    $(".recv_files").mustache("tpl_recv_files",
                             {
                                 serno: x.serno,
                                 day: x.day,
                                 fileDetails: x.fileDetails,
                                 jobIDattr: function(i) {if (this.jobID[i] != "NA") return 'class="job_id" job_id="' + this.jobID[i] + '"'; else return "";}
                             },
                             {
                                 method:"html"
                             }
                            );
    $(".recv_files").dialog(
        {
            top: $("html").offset().top,
            maxHeight: 600,
            dragable:true,
            closeOnEscape:true,
            width:900,
            title:"Files for receiver " + serno + " on " + x.day
        });
};

// @function show_error_dump: display a pop-up with info about a job error dump
//
// @param jobID: integer; ID of job with errors
//
// @details fetch error dump info, then chain to show_error_dump2

function show_error_dump(jobID) {
    motus_status_api("get_job_stackdump",
                     {
                         jobID: jobID
                     }, show_error_dump2);
};

// @function show_error_dump2: display a pop-up with info about a job error
//
// @param x: job stackdump info, as returned by the motus status API entry
// `get_job_stackdump` with `jobID` the ID of a job with an error


function show_error_dump2(x) {
    $(".job_dump").mustache("tpl_job_dump",
                             {
                                 jobID: x.jobID,
                                 URL: x.URL,
                                 path: x.path,
                                 fmt_size: fmt_filesize(x.size)
                             },
                             {
                                 method:"html"
                             }
                           );
    $(".job_dump").dialog(
        {
            top: $("html").offset().top,
            maxHeight: 600,
            dragable:true,
            closeOnEscape:true,
            width:700,
            title:"Error details for job " + x.jobID
        });
    $("#retry_job_button").button().on("click", on_click_retry_job);
    $("#retry_job_reply").toggle(false);
};

// @function retry_job: submit a job for retrying
//
// @param jobID: integer; ID of job with errors
// @param message: string (optional); message to add to job's log
//
// @details submit retry_job call, then chain to retry_job_reply

function retry_job(jobID, message) {
    motus_status_api("retry_job",
                     {
                         jobID: jobID,
                         message: message
                     }, retry_job_reply);
    $("#retry_job_reply").html("(waiting for reply from server)").toggle(true);
};

// @function retry_job_reply: show reply to "retry_job" in the job error details window
//
// @param x: retry_job reply, as returned by the motus status API entry


function retry_job_reply(x) {
    // show reply
    var msg = x.error;
    if (! msg) {
        msg = "These jobs will be retried: " + x.jobs.jobID.join(", ") + "<br>" + x.reply;
    }
    $("#retry_job_reply").html(msg);
};
