FROM node:18-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache python3 py3-pip git curl

# Copy package.json and package-lock.json (if available)
COPY package*.json ./

# Install Node.js dependencies if package.json exists
RUN if [ -f package.json ]; then npm install; else echo "No package.json found"; fi

# Copy the rest of the application
COPY . .

# Expose the port the app runs on
EXPOSE 3000

# Start the application (fallback to a simple HTTP server if no npm start script)
CMD if [ -f package.json ] && grep -q '"start"' package.json; then npm start; else python3 -m http.server 3000; fi


