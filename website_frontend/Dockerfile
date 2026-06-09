# Use the official, lightweight Nginx Alpine image
FROM nginx:alpine

# Copy the static HTML/JS file to the Nginx serving directory
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80 for the ECS networking
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]