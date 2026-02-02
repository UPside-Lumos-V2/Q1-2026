#!/bin/bash

# scripts/check_compliance.sh
# Purpose: Enforce strict file modification rules for auditors via CI

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "🔍 Compliance Check: Analyzing changed files..."

# Get list of changed files in this PR/Commit
# In GitHub Actions, we compare against the target branch (e.g., origin/incident/...)
CHANGED_FILES=$(git diff --name-only origin/main HEAD)

VIOLATIONS=0

for file in $CHANGED_FILES; do
    # Rule 1: No direct data manipulation
    if [[ "$file" == data/*.json ]]; then
        echo -e "${RED}❌ VIOLATION: Direct modification of data files is forbidden: $file${NC}"
        VIOLATIONS=$((VIOLATIONS+1))
    fi

    # Rule 2: No tampering with shared core logic
    if [[ "$file" == src/shared/* ]]; then
        echo -e "${RED}❌ VIOLATION: Modification of shared core logic is forbidden: $file${NC}"
        VIOLATIONS=$((VIOLATIONS+1))
    fi

    # Rule 3: No tampering with workflows
    if [[ "$file" == .github/* ]]; then
        echo -e "${RED}❌ VIOLATION: Modification of workflows is forbidden: $file${NC}"
        VIOLATIONS=$((VIOLATIONS+1))
    fi
done

if [ "$VIOLATIONS" -gt 0 ]; then
    echo ""
    echo -e "${RED}⛔ Compliance Check Failed with $VIOLATIONS violations.${NC}"
    echo "Auditors are only allowed to modify files in 'test/<Incident>/'."
    exit 1
else
    echo -e "${GREEN}✅ Compliance Check Passed.${NC}"
    exit 0
fi
