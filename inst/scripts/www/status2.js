// javascript for calling the status API and building DOM objects from results
// custom javascript to access the API directly from the browser / client
// Assumes jquery has already been loaded.

// assume there's an authTicket available in the auth_tkt cookie:
var authToken = decodeURIComponent(document.cookie.match(/(^|;)auth_tkt=([^;]*)(;|$)/)[2]);

// where to send API requests
var serverURL = "https://sgdata.motus.org/status2/";

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

// @function motus_status_api: call one of the motus status API entries
//
// @param api: entry, e.g. "authenticate_user", "status_api_info", "list_jobs", "subjobs_for_job", ...
// @param par: javascript object, passed as the POST parameter 'json'
// @param cb: callback; a function accepting a javascript object which is the return from the API
//
// @return nothing
// @note If `api` == `authenticate_user`, then the authToken returned by the API is saved in the
// global variable `authToken`, and this field is automatically added to any subsequent calls
// to `motus_status_api()`

function motus_status_api(api, par, cb) {
    if (api != "authenticate_user") {
        par.authToken = authToken;
    } else {
        // this was a call to the authenticate_user API entry, so
        // we wrap the callback in one that sets the global variable `authToken`,
        // thereby automatically making it available to subsequent API calls
        oldcb = cb;
        cb = function(x) {authToken = x.authToken; oldcb(x)};
    }
    $.post(serverURL + api, {"json":JSON.stringify(par)}, cb);
};

// @function show_job_list: display a list of jobs
//
// @param sortBy; sort order; default: "mtime"
// @param keyVal: last key for given sort order; default: null
//
// @details fetch summary list of jobs, then chains to show_job_list2

function show_job_list(sortBy, keyVal) {
  sortyBy = sortBy || "mtime desc";
  keyval = (keyVal === undefined) ? null : keyVal;
    motus_status_api("list_jobs",
                     {
                         options:{
                           includeUnknownProjects:true,
                           full:true
                         },
                         order:{
                           sortBy:sortBy,
                           keyVal:keyval
                         }
                     }, show_job_list2);
};

// @function show_job_list2: display the summary list of jobs
//
// @param x: summary list of jobs
//
// @details receive details for jobs and display them in main div

function show_job_list2(x) {
  x.__transpose__ = true;

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
  return (new Date(1000 * x)).toGMTString();
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

  $(".job_details").dialog({top:$("html").offset().top,maxHeight: 600, dragable:false, closeOnEscape:true, width:800, title:"Details for top-level job " + x.id[0]});
};

function on_click_jobs_table_row(event) {
  // extract the job_id from the "currentTarget" of the event; that will be
  // the jobs table row, as chosen by the dynamic selector in the .on("click", ...) call
  // which registered this handler.

  show_job_details(event.currentTarget.getAttribute("job_id"));
};

function initStatus2Page() {
  $.Mustache.addFromDom();
  $(show_job_list);
  // attach a click handler to rows in the job table
  // Because they haven't been created yet, we need an existing static selector (".job_list")
  // on which to hang the handler, which then delegates when an event hits the dynamic  selector (".jobs_table_row")
  $(".job_list").on("click", ".jobs_table_row", on_click_jobs_table_row);
};
