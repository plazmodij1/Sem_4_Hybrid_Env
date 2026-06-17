import { UserManager } from "https://esm.sh/oidc-client-ts";

const API_BASE_URL = "/api"; // Update this to your backend IP/Domain

const cognitoAuthConfig = {
    cognito_domain: "https://hybrid-cloud-login-proftask.auth.eu-central-1.amazoncognito.com",
    authority: "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_KCh4l3WkO",
    client_id: "4s5l2a5ba6mm2bb8gglbjjfm5f",
    redirect_uri: "https://fontys-proftask.lat/admin/",
    response_type: "code",
    scope: "email openid"
};

const userManager = new UserManager({
    authority: "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_KCh4l3WkO",
    client_id: "4s5l2a5ba6mm2bb8gglbjjfm5f",
    redirect_uri: "https://fontys-proftask.lat/admin/",
    response_type: "code",
    scope: "email openid"
});

document.getElementById('deployForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    // 1. Define the containerName variable FIRST so we can use it everywhere
    const containerName = document.getElementById('deployName').value;
    
    const payload = {
        user_id: document.getElementById('deployUser').value,
        role: "user",
        container_template: document.getElementById('deployTemplate').value,
        custom_name: containerName // Now we reference the variable here
    };

    try {
        const response = await fetch(`${API_BASE_URL}/deploy`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        if (!response.ok) throw new Error(await response.text());
        
        const data = await response.json();
        console.log(data);

        // --- THE UI UPDATE MAGIC (Moved INSIDE the try block, old alert removed!) --- 
        
        const targetUrl = `http://${containerName}.sandbox.fontys-proftask.lat`;
        
        const alertBox = document.getElementById('statusAlert');
        const alertMsg = document.getElementById('statusMessage');
        const linkBox = document.getElementById('statusLinkBox');

        alertMsg.innerText = `Deployment Triggered! Your container is spinning up.`;
        linkBox.innerHTML = `Access URL: <a href="${targetUrl}" target="_blank" class="text-blue-300 underline font-semibold hover:text-blue-200">${targetUrl}</a> <br><span class="text-gray-300 text-xs">(Note: It may take 1-2 minutes for AWS routing and DNS to fully resolve)</span>`;

        alertBox.classList.remove('hidden');

        document.getElementById('deployName').value = '';
        
    } catch (error) {
        console.error('Deployment Error:', error);
        alert('Failed to reach backend API. Check console for details.');
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

document.getElementById('deleteForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const containerName = document.getElementById('deleteTargetName').value;
    const activeAdmin = document.getElementById('adminUser').value;

    if(!confirm(`Are you absolutely sure you want to destroy ${containerName}? This cannot be undone.`)) return;

    try {
        // THE FIX: Container name in the path, user_id and role in the query parameters
        const deleteUrl = `${API_BASE_URL}/deployments/${containerName}?user_id=${activeAdmin}&role=admin`;
        
        const response = await fetch(deleteUrl, {
            method: 'DELETE' // No headers or body needed for query parameters!
        });
        
        if (!response.ok) throw new Error(await response.text());
        
        alert(`Successfully destroyed ${containerName}.`);
        document.getElementById('deleteTargetName').value = '';
        
    } catch (error) {
        console.error('Teardown Error:', error);
        alert(`Teardown Failed. Check browser console for details.`);
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
} else {
    updateUi();
}