document.addEventListener("DOMContentLoaded", init);

async function init() {
  try {
    const configResponse = await fetch("assets/config.json");
    if (!configResponse.ok) throw new Error("Failed to load configuration");
    const config = await configResponse.json();

    const oryUrl = config.oryUrl || "https://login.kiwix.org";
    const apps = config.apps || [];

    await checkAuthStatus(oryUrl, apps);
  } catch (error) {
    console.error("Initialization error:", error);
    showError("Unable to load application configuration.");
  }
}

async function checkAuthStatus(oryUrl, apps) {
  const subtitle = document.getElementById("subtitle");
  const spinner = document.getElementById("spinner");
  const content = document.getElementById("content");

  try {
    const response = await fetch(`${oryUrl}/sessions/whoami`, {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
      credentials: "include",
    });

    if (response.ok) {
      const session = await response.json();
      handleLoggedIn(session, oryUrl, apps);
    } else {
      handleLoggedOut(oryUrl);
    }
  } catch (error) {
    console.error("Auth check error:", error);
    handleLoggedOut(oryUrl);
  } finally {
    spinner.classList.add("hidden");
    content.classList.remove("hidden");
  }
}

function handleLoggedIn(session, oryUrl, apps) {
  const subtitle = document.getElementById("subtitle");
  const userDetails = document.getElementById("user-details");
  const userNameElement = document.getElementById("user-name");
  const userStatusElement = document.getElementById("user-status");
  const dashboard = document.getElementById("dashboard");

  subtitle.textContent = "You are currently logged in.";

  // Attempt to extract name/email from Ory traits
  let displayName = "User";
  if (session.identity && session.identity.traits) {
    const traits = session.identity.traits;
    displayName = traits.name || traits.email;
  }
  userNameElement.textContent = displayName;

  let aal = "Standard";
  if (session.authenticator_assurance_level === "aal2") {
    aal = "Logged in with 2FA";
  } else if (session.authenticator_assurance_level === "aal1") {
    aal = "Standard (No 2FA)";
  }
  userStatusElement.textContent = aal;

  userDetails.classList.remove("hidden");

  // Build Dashboard Tiles for Logged-In User
  dashboard.innerHTML = "";

  apps.forEach((app) => {
    dashboard.appendChild(
      createTile(app.name, app.url, app.icon || "fas fa-external-link-alt"),
    );
  });

  dashboard.appendChild(
    createTile(
      "Settings",
      `${oryUrl}/ui/settings?return_to=${encodeURIComponent(window.location.href)}`,
      "fas fa-cog",
      true,
    ),
  );

  const logoutTile = createTile("Logout", "#", "fas fa-sign-out-alt", true);
  logoutTile.addEventListener("click", async (e) => {
    e.preventDefault();
    try {
      const resp = await fetch(`${oryUrl}/self-service/logout/browser`, {
        method: "GET",
        headers: { Accept: "application/json" },
        credentials: "include",
      });
      const data = await resp.json();
      if (data.logout_token) {
        // Perform the logout in the background
        await fetch(
          `${oryUrl}/self-service/logout?token=${data.logout_token}`,
          {
            method: "GET",
            headers: { Accept: "application/json" },
            credentials: "include",
          },
        );
        window.location.reload();
      } else if (data.logout_url) {
        await fetch(data.logout_url, {
          method: "GET",
          headers: { Accept: "application/json" },
          credentials: "include",
        });
        window.location.reload();
      }
    } catch (err) {
      console.error("Logout error:", err);
      window.location.reload();
    }
  });
  dashboard.appendChild(logoutTile);
}

function handleLoggedOut(oryUrl) {
  const subtitle = document.getElementById("subtitle");
  const dashboard = document.getElementById("dashboard");

  subtitle.textContent = "You are not logged in.";

  dashboard.innerHTML = "";
  dashboard.appendChild(
    createTile(
      "Login",
      `${oryUrl}/ui/login?return_to=${encodeURIComponent(window.location.href)}`,
      "fas fa-sign-in-alt",
    ),
  );
  dashboard.appendChild(
    createTile(
      "Register",
      `${oryUrl}/ui/registration?return_to=${encodeURIComponent(window.location.href)}`,
      "fas fa-user-plus",
    ),
  );
  dashboard.appendChild(
    createTile(
      "Recover Account",
      `${oryUrl}/ui/recovery?return_to=${encodeURIComponent(window.location.href)}`,
      "fas fa-key",
      true,
    ),
  );
}

function createTile(name, url, iconClass, isAction = false) {
  const a = document.createElement("a");
  a.href = url;
  a.className = `tile ${isAction ? "action-tile" : ""}`;

  const i = document.createElement("i");
  i.className = iconClass;

  const span = document.createElement("span");
  span.textContent = name;

  a.appendChild(i);
  a.appendChild(span);

  return a;
}

function showError(message) {
  const subtitle = document.getElementById("subtitle");
  const spinner = document.getElementById("spinner");

  spinner.classList.add("hidden");
  subtitle.textContent = message;
  subtitle.style.color = "red";
}
