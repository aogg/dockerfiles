ARG FROM_ARG=node:22-alpine

FROM ${FROM_ARG}

ARG NPM_ARGS

# Install agent-browser
RUN npm install agent-browser $NPM_ARGS -g

# Start agent-browser
CMD ["agent-browser"]
