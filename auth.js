/* Authentication uses oidc-client-ts 3.3.0 (Apache-2.0). See AUTHENTICATION.md. */
(async function () {
  "use strict";
  const app = document.getElementById("app");
  const signedOut = document.getElementById("signedOut");
  const identity = document.getElementById("identity");
  const message = document.getElementById("authMessage");
  const login = document.getElementById("signIn");
  const logout = document.getElementById("signOut");
  let manager;
  function render(user) {
    const active = !!user && !user.expired;
    app.hidden = !active;
    signedOut.hidden = active;
    login.hidden = active;
    logout.hidden = !active;
    identity.textContent = active ? "Signed in as " + (user.profile.email || user.profile.sub) : "Signed out";
  }
  function showError(text) { message.textContent = text; }
  render(null);
  login.disabled = true;
  try {
    if (!window.oidc) throw new Error("Authentication library unavailable");
    const response = await fetch("auth-config.json", { cache: "no-store" });
    if (!response.ok) throw new Error("Authentication configuration unavailable");
    const config = await response.json();
    manager = new oidc.UserManager({
      authority: config.authority,
      client_id: config.client_id,
      redirect_uri: config.redirect_uri,
      response_type: "code",
      scope: "openid email profile",
      automaticSilentRenew: false,
      monitorSession: false,
      loadUserInfo: false,
      userStore: new oidc.WebStorageStateStore({ store: window.sessionStorage }),
      stateStore: new oidc.WebStorageStateStore({ store: window.sessionStorage }),
      metadata: {
        issuer: config.authority,
        authorization_endpoint: config.domain + "/oauth2/authorize",
        token_endpoint: config.domain + "/oauth2/token",
        userinfo_endpoint: config.domain + "/oauth2/userInfo",
        jwks_uri: config.authority + "/.well-known/jwks.json"
      }
    });
    window.getAccessToken = async function () {
      const user = await manager.getUser();
      if (!user || user.expired) throw new Error("Please sign in again.");
      return user.access_token;
    };
    manager.events.addAccessTokenExpired(async function () {
      render(null);
      await manager.removeUser();
      showError("Your session expired. Please sign in again.");
    });
    login.onclick = async function () {
      message.textContent = "";
      login.disabled = true;
      try { await manager.signinRedirect({ prompt: "login" }); }
      catch (_) { showError("Unable to open sign-in. Please try again."); login.disabled = false; }
    };
    logout.onclick = async function () {
      render(null);
      try {
        await manager.removeUser();
        await manager.clearStaleState();
        const url = new URL(config.domain + "/logout");
        url.searchParams.set("client_id", config.client_id);
        url.searchParams.set("logout_uri", config.redirect_uri);
        window.location.assign(url.toString());
      } catch (_) { showError("Unable to finish sign-out. Please retry."); logout.hidden = false; }
    };
    const params = new URLSearchParams(window.location.search);
    if (params.has("code") || params.has("error")) {
      try { await manager.signinRedirectCallback(); }
      catch (_) {
        await manager.removeUser();
        showError("Sign-in was canceled or could not be verified. Please try again.");
      } finally { window.history.replaceState({}, document.title, "/"); }
    }
    const user = await manager.getUser();
    if (user && user.expired) await manager.removeUser();
    render(user);
    await manager.clearStaleState();
    login.disabled = false;
  } catch (_) {
    render(null);
    showError("Sign-in is unavailable. Reload the page to try again.");
  }
})();
