FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application files
COPY index.js ./

# Set timezone to Europe/London for proper scheduling
ENV TZ=Europe/London

# Run as non-root user
USER node

CMD ["node", "index.js"]