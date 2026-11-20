var apiConfiguration;
var aiResultId = null; // id of the saved Bedrock draft, set after Generate draft

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
            const requireScope = /^\/(transcribe|broadcast)(?:[/?]|$)/.test(path);
            options.headers = Object.assign({}, options.headers, {
                Authorization: "Bearer " + (await window.getAccessToken(requireScope)),
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

async function transcribeAudio(file, useSample = false) {
    const path = useSample ? '/transcribe?sample=true' : '/transcribe?filename=' + encodeURIComponent(file.name);
    const data = await requestAPI(path, {
        method: 'POST',
        headers: { 'Content-Type': 'application/octet-stream' },
        body: useSample ? undefined : await file.arrayBuffer(),
    });
    if (!data.jobId) throw new Error('The transcription service did not return a job ID.');
    // Each status check is a separate request; no Lambda waits for the job.
    for (let attempt = 0; attempt < 300; attempt++) {
        await new Promise(resolve => setTimeout(resolve, 3000));
        const result = await requestAPI('/transcribe/' + encodeURIComponent(data.jobId));
        if (result.status === 'completed') return result;
        if (result.status === 'failed') throw new Error(result.error || 'Transcription failed.');
        if (!['queued', 'in_progress'].includes(result.status)) {
            throw new Error('Unexpected transcription status.');
        }
    }
    throw new Error('Transcription is taking longer than expected. The job may still be running.');
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
        var transcribeResult = await transcribeAudio(file);

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
        broadcastStatus.textContent = broadcastResult.message || "Recap queued.";
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

async function runTranscribe(useSample = false) {
    var fileInput = document.getElementById("audioInput");
    var button = document.getElementById("runTranscribe");
    var status = document.getElementById("transcribeStatus");
    var result = document.getElementById("transcribeResult");

    var file = fileInput.files[0];
    if (!file && !useSample) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = "Please select an audio file first.";
        return;
    }
    const sampleButton = document.getElementById("runSampleTranscribe");
    button.disabled = true;
    if (sampleButton) sampleButton.disabled = true;
    status.className = "mt-3 text-sm text-blue-600";
    status.textContent = "Reading audio file...";

    try {
        status.textContent = "Transcribing audio file...";
        var data = await transcribeAudio(file, useSample);
        result.value = data.transcript;
        status.className = "mt-3 text-sm text-green-600";
        status.textContent = "Transcription completed.";
    } catch (error) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = "Error: " + error.message;
    } finally {
        button.disabled = false;
        if (sampleButton) sampleButton.disabled = false;
    }
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
            body: JSON.stringify({
                text: text,
                approved: true,
                meeting_id: aiMeetingId(),
            }),
        });
        result.value = data.result;
        status.textContent =
            "Draft generated by " +
            data.modelId +
            ". Review and correct it below.";
        // The draft is saved with the meeting, so it can be accepted or corrected
        aiResultId = data.aiResultId || null;
        if (data.saveError) status.textContent += " " + data.saveError;
        else if (aiResultId) status.textContent += " Saved as unreviewed.";
        showAIReview(aiResultId !== null);
    } catch (error) {
        status.className = "mt-3 text-sm text-red-600";
        status.textContent = error.message;
    } finally {
        button.disabled = false;
    }
}

document.getElementById("aiInput").addEventListener("input", function () {
    aiResultId = null;
    showAIReview(false);
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

        addMeetingTitle(row, meeting);
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

    // The AI draft is saved with the meeting picked here
    var aiSelect = document.getElementById("aiMeeting");
    aiSelect.textContent = "";
    meetings.forEach(function (meeting) {
        var option = document.createElement("option");
        option.value = meeting.id;
        option.textContent = meeting.title;
        aiSelect.appendChild(option);
    });

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
        if (document.getElementById("onlyMine").checked && !item.mine) return;
        var row = document.createElement("tr");
        row.className = "border-b border-slate-100";
        addCell(row, item.description);
        addCell(row, item.assignee);
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
    document.getElementById("meetingDetail").hidden = true;
    document.getElementById("searchResults").textContent = "";
    setMessage("searchStatus", "");
    document.getElementById("reminderList").textContent = "";
    setMessage("reminderStatus", "");
    aiResultId = null;
    showAIReview(false);
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
    // Participants are typed as emails separated by commas
    var participants = document
        .getElementById("meetingParticipants")
        .value.split(",")
        .map(function (email) {
            return email.trim();
        })
        .filter(function (email) {
            return email !== "";
        });
    saveChange(
        "/meetings",
        "POST",
        {
            title: document.getElementById("meetingTitle").value,
            meeting_date: document.getElementById("meetingDate").value,
            agenda: document.getElementById("meetingAgenda").value,
            participants: participants,
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

// ---------- Meeting details: agenda, notes and decisions ----------

var openMeetingId = null;

// The meeting title is a button that opens the details card
function addMeetingTitle(row, meeting) {
    var cell = document.createElement("td");
    cell.className = "px-3 py-2";
    var button = document.createElement("button");
    button.type = "button";
    button.className = "text-indigo-700 underline";
    button.textContent = meeting.title;
    button.onclick = function () {
        openMeeting(meeting.id);
    };
    cell.appendChild(button);
    row.appendChild(cell);
}

function openMeeting(id) {
    openMeetingId = id;
    setMessage("notesMessage", "Loading meeting...");
    requestAPI("/meetings/" + id)
        .then(function (meeting) {
            document.getElementById("meetingDetail").hidden = false;
            setMessage("detailTitle", meeting.title);
            var names = meeting.participants.map(function (person) {
                return person.name;
            });
            setMessage(
                "detailInfo",
                meeting.meeting_date.slice(0, 10) +
                    " | Participants: " +
                    (names.length === 0 ? "none" : names.join(", ")),
            );
            document.getElementById("detailAgenda").value = meeting.agenda;
            document.getElementById("detailNotes").value = meeting.notes;
            setMessage("notesMessage", "");
            setMessage("decisionError", "");
            showDecisions(meeting.decisions);
        })
        .catch(function (error) {
            setMessage(
                "notesMessage",
                "Could not load meeting: " + error.message,
            );
        });
}

function showDecisions(decisions) {
    var list = document.getElementById("decisionList");
    list.textContent = "";
    if (decisions.length === 0) {
        var none = document.createElement("li");
        none.textContent = "No decisions recorded yet.";
        list.appendChild(none);
    }
    decisions.forEach(function (decision) {
        var item = document.createElement("li");
        item.textContent = decision.description + " (" + decision.author + ")";
        list.appendChild(item);
    });
}

function saveNotes() {
    setMessage("notesMessage", "Saving...");
    requestAPI("/meetings/" + openMeetingId, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            notes: document.getElementById("detailNotes").value,
        }),
    })
        .then(function () {
            setMessage("notesMessage", "Saved.");
        })
        .catch(function (error) {
            setMessage("notesMessage", "Could not save: " + error.message);
        });
}

function addDecision(event) {
    event.preventDefault();
    var form = event.target;
    setMessage("decisionError", "");
    requestAPI("/meetings/" + openMeetingId + "/decisions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            description: document.getElementById("decisionText").value,
        }),
    })
        .then(function () {
            form.reset();
            openMeeting(openMeetingId); // reload so the new decision shows up
        })
        .catch(function (error) {
            setMessage("decisionError", "Could not save: " + error.message);
        });
}

// ---------- Search meeting history ----------

function addResult(list, text) {
    var item = document.createElement("li");
    item.textContent = text;
    list.appendChild(item);
}

function searchHistory(event) {
    event.preventDefault();
    var list = document.getElementById("searchResults");
    list.textContent = "";
    setMessage("searchStatus", "Searching...");
    var text = document.getElementById("searchText").value;
    requestAPI("/search?q=" + encodeURIComponent(text))
        .then(function (data) {
            data.meetings.forEach(function (m) {
                addResult(list, "Meeting: " + m.title);
            });
            data.decisions.forEach(function (d) {
                addResult(
                    list,
                    "Decision: " + d.description + " (" + d.meeting + ")",
                );
            });
            data.action_items.forEach(function (a) {
                addResult(
                    list,
                    "Action item: " +
                        a.description +
                        " (" +
                        a.meeting +
                        ", " +
                        a.status +
                        ")",
                );
            });
            setMessage(
                "searchStatus",
                list.children.length === 0 ? "Nothing found." : "",
            );
        })
        .catch(function (error) {
            setMessage("searchStatus", "Search failed: " + error.message);
        });
}

// ---------- Reminders ----------

function sendReminders() {
    var list = document.getElementById("reminderList");
    list.textContent = "";
    setMessage("reminderStatus", "Sending...");
    requestAPI("/reminders/run", { method: "POST" })
        .then(function (data) {
            data.reminders.forEach(function (r) {
                addResult(
                    list,
                    r.owner +
                        ": " +
                        r.description +
                        " (due " +
                        r.due_date +
                        ")",
                );
            });
            setMessage(
                "reminderStatus",
                data.sent === 0
                    ? "No action items need a reminder."
                    : "Sent " + data.sent + " reminder(s) through SNS.",
            );
        })
        .catch(function (error) {
            setMessage(
                "reminderStatus",
                "Could not send reminders: " + error.message,
            );
        });
}

// ---------- Save and review AI drafts ----------

function aiMeetingId() {
    var select = document.getElementById("aiMeeting");
    return select ? select.value : "";
}

function showAIReview(visible) {
    var box = document.getElementById("aiReview");
    if (box) box.hidden = !visible;
}

// Accept the draft as it is, or save the edited text as a correction
function reviewAI(reviewStatus) {
    var status = document.getElementById("aiStatus");
    status.className = "mt-3 text-sm";
    var data = { review_status: reviewStatus };
    if (reviewStatus === "corrected")
        data.corrected_text = document.getElementById("aiResult").value;
    requestAPI("/ai-results/" + aiResultId, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
    })
        .then(function () {
            status.textContent =
                reviewStatus === "accepted"
                    ? "Draft accepted and saved."
                    : "Your corrections were saved.";
            showAIReview(false);
        })
        .catch(function (error) {
            status.className = "mt-3 text-sm text-red-600";
            status.textContent = "Could not save the review: " + error.message;
        });
}
