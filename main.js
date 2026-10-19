var apiConfiguration;

function requestAPI(path, options) {
  if (!apiConfiguration) {
    apiConfiguration = fetch("auth-config.json", { cache: "no-store" })
      .then(function (response) {
        if (!response.ok) throw new Error("Unable to load application configuration.");
        return response.json();
      })
      .catch(function (error) { apiConfiguration = null; throw error; });
  }
  return apiConfiguration.then(function (config) {
    if (!config.api_url) throw new Error("API is not configured. Redeploy the application configuration.");
    return fetch(config.api_url.replace(/\/$/, "") + path, options);
  }).then(function (response) {
    return response.json().then(function (data) {
      if (!response.ok) throw new Error(data.error || "Request failed (" + response.status + ").");
      return data;
    });
  });
}

function testBackend() {
  var result = document.getElementById("backendResult");
  result.textContent = "Loading...";

  requestAPI("/health")
    .then(function (data) { result.textContent = JSON.stringify(data, null, 2); })
    .catch(function (error) { result.textContent = "Error: " + error; });
}

function runAI() {
  var result = document.getElementById("aiResult");
  var text = document.getElementById("aiInput").value;

  if (text.trim() === "") {
    result.textContent = "Please enter some text first.";
    return;
  }

  result.textContent = "Processing...";

  requestAPI("/ai-sample", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: text })
  })
    .then(function (data) { result.textContent = JSON.stringify(data, null, 2); })
    .catch(function (error) { result.textContent = "Error: " + error; });
}
