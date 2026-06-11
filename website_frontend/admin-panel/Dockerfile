FROM nginx:alpine

# Remove the default Nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy our custom configuration
COPY nginx.conf /etc/nginx/conf.d/

# Copy the HTML file into the container
COPY index.html /usr/share/nginx/html/

# Expose port 80 for AWS Fargate
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]