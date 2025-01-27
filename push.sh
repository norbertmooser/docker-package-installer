#!/bin/bash

# Exit on any error
set -e

# Add all changes
git add .

# Commit with timestamp
git commit -m "Commit on $(date '+%Y-%m-%d %H:%M:%S')"

# Push to specified branch
git push origin main
