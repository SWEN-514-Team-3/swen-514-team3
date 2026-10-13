var API_URL = "https://API-ID.execute-api.us-east-1.amazonaws.com";

function testBackend() {
  var result = document.getElementById("backendResult");
  result.textContent = "Loading...";

  fetch(API_URL + "/health")
    .then(function (response) { return response.json(); })
    .then(function (data) { result.textContent = JSON.stringify(data, null, 2); })
    .catch(function (error) { result.textContent = "Error: " + error; });
}

function runAI() {
  var result = document.getElementById("aiResult");
  var text = document.getElementById("aiInput").value;

  if (text === "") {
    result.textContent = "Please enter some text first.";
    return;
  }

  result.textContent = "Processing...";

  fetch(API_URL + "/ai-sample", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: text })
  })
    .then(function (response) { return response.json(); })
    .then(function (data) { result.textContent = JSON.stringify(data, null, 2); })
    .catch(function (error) { result.textContent = "Error: " + error; });
}
