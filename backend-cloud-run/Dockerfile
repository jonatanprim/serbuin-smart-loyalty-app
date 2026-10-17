# Use the official lightweight Node.js 20 image
FROM node:20-slim

# Set working directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Copy application code
COPY . ./

# Cloud Run defaults to port 8080
ENV PORT=8080
EXPOSE 8080

# Run the web service on container startup
CMD ["npm", "start"]
