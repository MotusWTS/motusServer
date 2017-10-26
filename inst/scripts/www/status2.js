// javascript for calling the status API and building DOM objects from results
// custom javascript to access the API directly from the browser / client
// Assumes jquery has already been loaded.

// assume there's an authTicket available in the auth_tkt cookie:
var authToken = decodeURIComponent(document.cookie.match(/(^|;)auth_tkt=([^;]*)(;|$)/)[2]);

// where to send API requests
var serverURL = "https://sgdata.motus.org/status2/";

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

// @function show_job_details2: display a pop-up div with details of a job and its subjobs
//
// @param x: detailed list of subjobs for a job (including the job itself), as
// returned by the reply to the motus status API entry `list_jobs`
//
// @details receive details for subjobs and display them in a popup div

function show_job_details2(x) {
    console.log(JSON.stringify(x))
};
