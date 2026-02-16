#!/bin/bash

# Starta Claude Code sandbox

# Kontrollera att Docker körs
if ! docker info > /dev/null 2>&1; then
    echo "Docker är inte igång. Starta Docker Desktop först."
    exit 1
fi

# Bygg och starta interaktivt (använder credentials från ~/.claude eller ANTHROPIC_API_KEY)
docker compose run --rm claude-sandbox-mock-pad
