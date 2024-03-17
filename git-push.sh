#!/bin/bash

set -e

# Check if a commit message is provided
if [ $# -eq 0 ]; then
    echo "Error: No commit message provided."
    echo "Usage: $0 \"Your commit message here\""
    exit 1
fi

# Add all changes
git add -A

# Commit with the provided message
git commit -m "$1"

# Push to the remote repository
git push

echo "Changes committed and pushed successfully!"
