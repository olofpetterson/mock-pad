FROM node:20

# Installera Claude Code globalt
RUN npm install -g @anthropic-ai/claude-code

# Skapa en icke-root användare
RUN useradd -m -s /bin/bash claudeuser

# Skapa arbetskatalog och ge användaren rättigheter
WORKDIR /workspace
RUN chown claudeuser:claudeuser /workspace

# Byt till icke-root användare
USER claudeuser

CMD ["claude", "--dangerously-skip-permissions"]

