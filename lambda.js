exports.handler = async (event) => {
    // 1. Grab the path from the ALB event
    const path = event.path || '/';

    // ------------------------------------------------------
    // Route 1: The Health Check
    // ------------------------------------------------------
    if (path === '/health') {
        return {
            statusCode: 200,
            statusDescription: "200 OK",
            isBase64Encoded: false,
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ status: "healthy" })
        };
    } 
    // ------------------------------------------------------
    // Route 2: The Root Path
    // ------------------------------------------------------
    else if (path === '/') {
        return {
            statusCode: 200,
            statusDescription: "200 OK",
            isBase64Encoded: false,
            headers: {
                "Content-Type": "text/plain" 
            },
            body: "aws web server"
        };
    } 
    // ------------------------------------------------------
    // Fallback: 404 Not Found
    // ------------------------------------------------------
    else {
        return {
            statusCode: 404,
            statusDescription: "404 Not Found",
            isBase64Encoded: false,
            headers: {
                "Content-Type": "text/plain"
            },
            body: "404 Not Found"
        };
    }
};