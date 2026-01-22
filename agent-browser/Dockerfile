ARG FROM_ARG=node:22-alpine

FROM ${FROM_ARG}

ARG NPM_ARGS

# Install agent-browser
RUN npm install agent-browser $NPM_ARGS -g

# Expose default port
EXPOSE 3000

# Start agent-browser
CMD ["agent-browser"]
