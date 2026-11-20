var apiConfiguration;

function requestAPI(path, options) {
    if (!apiConfiguration) {
        apiConfiguration = fetch("auth-config.json", { cache: "no-store" })
            .then(function (response) {
                if (!response.ok)
                    throw new Error(
                        "Unable to load application configuration.",
                    );
                return response.json();
            })
            .catch(function (error) {
                apiConfiguration = null;
                throw error;
            });
    }
    return apiConfiguration
        .then(async function (config) {
            if (!config.api_url)
                throw new Error(
                    "API is not configured. Redeploy the application configuration.",
                );
            // Every API request carries the signed-in user's Cognito token.
            if (!window.getAccessToken)
                throw new Error("Please sign in first.");
            options = options || {};
            options.headers = Object.assign({}, options.headers, {
                Authorization: "Bearer " + (await window.getAccessToken()),
            });
            return fetch(config.api_url.replace(/\/$/, "") + path, options);
        })
        .then(function (response) {
            if (response.status === 401)
                throw new Error("Your session expired. Please sign in again.");
            return response.json().then(function (data) {
                if (!response.ok)
                    throw new Error(
                        data.error ||
                            "Request failed (" + response.status + ").",
                    );
                return data;
            });
        });
}

async function sendRecap() {
    // inputs
    var meetingAudio = document.getElementById("meeting-audio");
    var emailList = document.getElementById("email-list");
    var meetingName = document
        .getElementById("meeting-name")
        .textContent.trim();

    // status labels for sending process
    var transcriptionStatus = document.getElementById("transcription-status");
    var summarizationStatus = document.getElementById("summarization-status");
    var broadcastStatus = document.getElementById("broadcast-status");

    var file = meetingAudio.files[0];
    var currentStep = "transcription";

    try {
        // initial statuses
        transcriptionStatus.className = "mt-3 text-sm text-blue-600";
        transcriptionStatus.textContent = "Reading audio file...";

        summarizationStatus.className = "mt-3 text-sm text-slate-600";
        summarizationStatus.textContent =
            "Waiting for meeting transcription...";

        broadcastStatus.className = "mt-3 text-sm text-slate-600";
        broadcastStatus.textContent = "Waiting for meeting summary...";

        // run transcribe
        var arrayBuffer = await file.arrayBuffer();
        var transcribeResult = await requestAPI(
            "/transcribe?filename=" + encodeURIComponent(file.name),
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/octet-stream",
                },
                body: arrayBuffer,
            },
        );

        var transcriptionText = transcribeResult.transcript;
        transcriptionStatus.className = "mt-3 text-sm text-green-600";
        transcriptionStatus.textContent = "Transcription completed.";

        // run bedrock summarizer
        currentStep = "summarization";
        summarizationStatus.className = "mt-3 text-sm text-blue-600";
        summarizationStatus.textContent =
            "Summarizing the meeting transcription...";
        var aiSampleResult = await requestAPI("/ai-sample", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                text: transcriptionText,
                approved: true,
            }),
        });

        var summaryText = aiSampleResult.result;
        summarizationStatus.className = "mt-3 text-sm text-green-600";
        summarizationStatus.textContent = "Summary generated.";

        // run SNS broadcast
        currentStep = "broadcast";
        broadcastStatus.className = "mt-3 text-sm text-blue-600";
        broadcastStatus.textContent =
            "Broadcasting the summary to team members...";

        var emails = emailList.value
            .split(",")
            .map(function (e) {
                return e.trim();
            })
            .filter(Boolean);

        var broadcastResult = await requestAPI("/broadcast", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                meetingName: meetingName,
                summary: summaryText,
                recipients: emails,
            }),
        });

        broadcastStatus.className = "mt-3 text-sm text-green-600";
        broadcastStatus.textContent = "Emails sent succesfully.";
    } catch (error) {
        console.error("Error during " + currentStep + ":", error);
        var errorMessage =
            error && error.message
                ? error.message
                : "An unexpected error occurred.";

        if (currentStep === "transcription") {
            transcriptionStatus.className = "mt-3 text-sm text-red-600";
            transcriptionStatus.textContent =
                "Transcription failed: " + errorMessage;
            summarizationStatus.textContent = "Canceled.";
            broadcastStatus.textContent = "Canceled.";
        } else if (currentStep === "summarization") {
            summarizationStatus.className = "mt-3 text-sm text-red-600";
            summarizationStatus.textContent =
                "Summarization failed: " + errorMessage;
            broadcastStatus.textContent = "Canceled.";
        } else if (currentStep === "broadcast") {
            broadcastStatus.className = "mt-3 text-sm text-red-600";
            broadcastStatus.textContent = "Broadcast failed: " + errorMessage;
        }
    }
}

// handle joining and leaving meetings
function joinMeeting(title) {
    document.getElementById("meeting-name").textContent = title;
    document.getElementById("meeting-audio").value = "";

    var tStatus = document.getElementById("transcription-status");
    tStatus.className = "mt-1 text-sm text-slate-500";
    tStatus.textContent = "Waiting for audio...";

    var sStatus = document.getElementById("summarization-status");
    sStatus.className = "mt-1 text-sm text-slate-500";
    sStatus.textContent = "Waiting for meeting transcription...";

    var bStatus = document.getElementById("broadcast-status");
    bStatus.className = "mt-1 text-sm text-slate-500";
    bStatus.textContent = "Waiting for meeting summary...";

    document.getElementById("current-meeting").classList.remove("hidden");
}

function leaveMeeting() {
    document.getElementById("current-meeting").classList.add("hidden");
    document.getElementById("meeting-name").textContent = "";
}

async function runTranscribe() {
    var fileInput = document.getElementById("audioInput");
    var button = document.getElementById("runTranscribe");
    var status = document.getElementById("transcribeStatus");
    var result = document.getElementById("transcribeResult");

    var file = fileInput.files[0];
    if (!file) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = "Please select an audio file first.";
        return;
    }
    button.disabled = true;
    status.className = "mt-3 text-sm text-blue-600";
    status.textContent = "Reading audio file...";

    try {
        var arrayBuffer = await file.arrayBuffer();
        status.textContent = "Transcribing audio file...";
        var data = await requestAPI(
            "/transcribe?filename=" + encodeURIComponent(file.name),
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/octet-stream",
                },
                body: arrayBuffer,
            },
        );
        result.value = data.transcript;
        status.className = "mt-3 text-sm text-green-600";
        status.textContent = "Transcription completed.";
    } catch (error) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = "Error: " + error.message;
    } finally {
        button.disabled = false;
    }
}

function testBackend() {
    var result = document.getElementById("backendResult");
    result.textContent = "Loading...";

    requestAPI("/health")
        .then(function (data) {
            result.textContent = JSON.stringify(data, null, 2);
        })
        .catch(function (error) {
            result.textContent = "Error: " + error;
        });
}

async function runAI() {
    var result = document.getElementById("aiResult");
    var button = document.getElementById("runAI");
    var text = document.getElementById("aiInput").value;
    var status = document.getElementById("aiStatus");
    status.className = "mt-3 text-sm";
    result.value = "";
    if (!text.trim()) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = "Please enter meeting text first.";
        return;
    }
    if (!document.getElementById("aiApproved").checked) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = "Review and approve the source text first.";
        return;
    }
    button.disabled = true;
    status.textContent = "Generating a draft...";
    try {
        var data = await requestAPI("/ai-sample", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ text: text, approved: true }),
        });
        result.value = data.result;
        status.textContent =
            "Draft generated by " +
            data.modelId +
            ". Review and correct it below.";
    } catch (error) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = error.message;
    } finally {
        button.disabled = false;
    }
}

document.getElementById("aiInput").addEventListener("input", function () {
    document.getElementById("aiStatus").className = "mt-3 text-sm";
    document.getElementById("aiApproved").checked = false;
    document.getElementById("aiResult").value = "";
    document.getElementById("aiStatus").textContent =
        "Review the edited source before generating another draft.";
});

// ---------- Meeting and action item lists ----------

var FILTER_ON =
    "rounded-lg bg-indigo-600 px-3 py-1.5 text-sm font-medium text-white";
var FILTER_OFF =
    "rounded-lg bg-slate-200 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-300";
var GROUP_NAMES = { open: "Open", overdue: "Overdue", completed: "Completed" };

var selectedGroup = "open";
var actionItems = [];

// Today as "YYYY-MM-DD" in the user's local time.
function today() {
    var now = new Date();
    var month = String(now.getMonth() + 1).padStart(2, "0");
    var day = String(now.getDate()).padStart(2, "0");
    return now.getFullYear() + "-" + month + "-" + day;
}

// Every action item belongs to exactly one group:
//   completed - its status is completed
//   overdue   - not completed, and the due date is before today
//   open      - everything else
function getActionGroup(item) {
    if (item.status === "completed") return "completed";
    if (item.due_date.slice(0, 10) < today()) return "overdue";
    return "open";
}

function setMessage(id, text) {
    document.getElementById(id).textContent = text;
}

function addCell(row, text) {
    var cell = document.createElement("td");
    cell.className = "px-3 py-2";
    cell.textContent = text;
    row.appendChild(cell);
}

function showMeetings(meetings) {
    var body = document.getElementById("meetingsBody");
    var todayStr = today();
    body.textContent = "";
    meetings.forEach(function (meeting) {
        var row = document.createElement("tr");
        row.className = "border-b border-slate-100";
        var meetingDate = meeting.meeting_date.slice(0, 10);

        addCell(row, meeting.title);
        addCell(row, meetingDate);

        if (meetingDate === todayStr) {
            var actionCell = document.createElement("td");
            actionCell.className = "px-3 py-2";
            var btn = document.createElement("button");
            btn.type = "button";
            btn.textContent = "Join";
            btn.className =
                "rounded-lg bg-indigo-600 px-3 py-1 text-xs font-medium text-white hover:bg-indigo-700";
            btn.onclick = function () {
                joinMeeting(meeting.title);
            };
            actionCell.appendChild(btn);
            row.appendChild(actionCell);
        } else {
            addCell(row, "—");
        }

        body.appendChild(row);
    });
    setMessage(
        "meetingsStatus",
        meetings.length === 0 ? "No meetings yet." : "",
    );

    // The "Add action item" form picks its meeting from this dropdown
    var select = document.getElementById("itemMeeting");
    select.textContent = "";
    meetings.forEach(function (meeting) {
        var option = document.createElement("option");
        option.value = meeting.id;
        option.textContent = meeting.title;
        select.appendChild(option);
    });
}

function showActionItems() {
    // Highlight the selected button
    Object.keys(GROUP_NAMES).forEach(function (group) {
        document.getElementById("filter-" + group).className =
            group === selectedGroup ? FILTER_ON : FILTER_OFF;
    });

    var body = document.getElementById("actionsBody");
    body.textContent = "";
    var count = 0;
    actionItems.forEach(function (item) {
        var group = getActionGroup(item);
        if (group !== selectedGroup) return;
        var row = document.createElement("tr");
        row.className = "border-b border-slate-100";
        addCell(row, item.description);
        addCell(row, item.due_date.slice(0, 10));
        addStatusDropdown(row, item);
        body.appendChild(row);
        count++;
    });
    setMessage(
        "actionsStatus",
        count === 0
            ? "No " +
                  GROUP_NAMES[selectedGroup].toLowerCase() +
                  " action items."
            : "",
    );
}

// Called by the Open / Overdue / Completed buttons
function showGroup(group) {
    selectedGroup = group;
    showActionItems();
}

function loadLists() {
    setMessage("meetingsStatus", "Loading meetings...");
    setMessage("actionsStatus", "Loading action items...");

    requestAPI("/meetings")
        .then(showMeetings)
        .catch(function (error) {
            setMessage(
                "meetingsStatus",
                "Could not load meetings: " + error.message,
            );
        });

    requestAPI("/action-items")
        .then(function (items) {
            actionItems = items;
            showActionItems();
        })
        .catch(function (error) {
            setMessage(
                "actionsStatus",
                "Could not load action items: " + error.message,
            );
        });
}

// Remove the lists from the page when the user signs out
function clearLists() {
    actionItems = [];
    document.getElementById("meetingsBody").textContent = "";
    document.getElementById("actionsBody").textContent = "";
    setMessage("meetingsStatus", "");
    setMessage("actionsStatus", "");
}

// ---------- Create meeting, add action item, change status ----------

// Sends a change to the API, then reloads the lists.
// Shows an error if it fails. Resolves to true if it worked, false if not.
function saveChange(path, method, data, errorId) {
    setMessage(errorId, "");
    return requestAPI(path, {
        method: method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
    })
        .then(function () {
            loadLists();
            return true;
        })
        .catch(function (error) {
            setMessage(errorId, "Could not save: " + error.message);
            return false;
        });
}

function createMeeting(event) {
    event.preventDefault();
    var form = event.target;
    saveChange(
        "/meetings",
        "POST",
        {
            title: document.getElementById("meetingTitle").value,
            meeting_date: document.getElementById("meetingDate").value,
        },
        "meetingFormError",
    ).then(function (saved) {
        if (saved) form.reset();
    });
}

function addActionItem(event) {
    event.preventDefault();
    var form = event.target;
    saveChange(
        "/action-items",
        "POST",
        {
            meeting_id: document.getElementById("itemMeeting").value,
            description: document.getElementById("itemDescription").value,
            assignee_email: document.getElementById("itemAssignee").value,
            due_date: document.getElementById("itemDueDate").value,
        },
        "itemFormError",
    ).then(function (saved) {
        if (saved) form.reset();
    });
}

// The Status cell is a dropdown, so a team member can change their own item
function addStatusDropdown(row, item) {
    var cell = document.createElement("td");
    cell.className = "px-3 py-2";
    var select = document.createElement("select");
    select.className = "rounded border border-slate-300 px-2 py-1";
    [
        ["open", "Open"],
        ["in_progress", "In progress"],
        ["completed", "Completed"],
    ].forEach(function (choice) {
        var option = document.createElement("option");
        option.value = choice[0];
        option.textContent = choice[1];
        option.selected = choice[0] === item.status;
        select.appendChild(option);
    });
    select.onchange = function () {
        saveChange(
            "/action-items/" + item.id,
            "PATCH",
            { status: select.value },
            "actionsStatus",
        ).then(function (saved) {
            if (!saved) select.value = item.status; // put the dropdown back
        });
    };
    cell.appendChild(select);
    row.appendChild(cell);
}

// auth.js calls these when the user signs in or out
window.onSignedIn = loadLists;
window.onSignedOut = clearLists;
