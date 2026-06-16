import { UserManager } from "https://esm.sh/oidc-client-ts";

const API_BASE_URL = "/api"; // Update this to your backend IP/Domain

const cognitoAuthConfig = {
    cognito_domain: "https://hybrid-cloud-login.auth.eu-central-1.amazoncognito.com",
    authority: "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_Ej0eZzr2O",
    client_id: "2tactjl76udjqkucb1ooqnb1lr",
    redirect_uri: "http://127.0.0.1:5500/website_frontend/index.html",
    response_type: "code",
    scope: "openid profile"
};

const userManager = new UserManager({
    authority: "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_Ej0eZzr2O",
    client_id: "2tactjl76udjqkucb1ooqnb1lr",
    redirect_uri: "http://127.0.0.1:5500/website_frontend/index.html",
    response_type: "code",
    scope: "openid profile"
});

// 1. Handle Deploy
document.getElementById('deployForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const payload = {
        user_id: document.getElementById('deployUser').value,
        role: "user",
        container_template: document.getElementById('deployTemplate').value,
        custom_name: document.getElementById('deployName').value
    };

    try {
        const response = await fetch(`${API_BASE_URL}/deploy`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await response.json();
        alert('Deployment Triggered! Check your Git repository.');
        console.log(data);
    } catch (error) {
        console.error('Deployment Error:', error);
        alert('Failed to reach backend API.');
    }
});

// 2. Handle Admin Update
document.getElementById('updateForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const payload = {
        user_id: document.getElementById('adminUser').value,
        role: "admin",
        container_name: document.getElementById('updateTargetName').value,
        updated_parameters: {
            listen_port: document.getElementById('updatePort').value || undefined,
            database_name: document.getElementById('updateDbName').value || undefined
        }
    };

    // Remove undefined parameters cleanly
    Object.keys(payload.updated_parameters).forEach(key => {
        if (payload.updated_parameters[key] === undefined) {
            delete payload.updated_parameters[key];
        }
    });

    try {
        const response = await fetch(`${API_BASE_URL}/config/update`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await response.json();
        alert('Config Update Pushed to Git!');
        console.log(data);
    } catch (error) {
        console.error('Update Error:', error);
        alert('Failed to reach backend API.');
    }
});

document.getElementById("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    await userManager.signinRedirect();
});

document.getElementById("logoutForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    userManager.removeUser();
    window.location.href = `${cognitoAuthConfig.cognito_domain}/logout?client_id=${cognitoAuthConfig.client_id}&redirect_uri=${encodeURIComponent(cognitoAuthConfig.redirect_uri)}&logout_uri=${cognitoAuthConfig.redirect_uri}&response_type=${cognitoAuthConfig.response_type}&scope=${cognitoAuthConfig.scope}`;
});

async function updateUi() {
    const user = await userManager.getUser();
    const updateForm = document.getElementById("updateForm");

    if (!user) {
        updateForm.classList.remove("unlocked");
        return
    }

    updateForm.classList.toggle("unlocked", user.profile["cognito:username"] === "admin");
    document.getElementById("loggedUser").innerHTML = `Logged in as: ${(user.profile["cognito:username"])}`;
}

if (window.location.search.includes("code=")) {
    userManager.signinRedirectCallback().then((user) => {
        window.history.replaceState({}, document.title, "/");
        updateUi();
    });
}