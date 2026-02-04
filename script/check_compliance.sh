#!/bin/bash

# scripts/check_compliance.sh
# Purpose: Enforce strict file modification rules for auditors via CI

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}Compliance Check${NC}"
echo "================"
echo ""

# Get list of changed files in this PR/Commit
CHANGED_FILES=$(git diff --name-only origin/main HEAD)
DELETED_FILES=$(git diff --name-only --diff-filter=D origin/main HEAD)

VIOLATIONS=0
WARNINGS=0

# === HARD VIOLATIONS (Block PR) ===
for file in $CHANGED_FILES; do
    # Rule 1: No direct data manipulation
    if [[ "$file" == data/*.json ]] || [[ "$file" == data/dataset.csv ]]; then
        echo -e "${RED}[VIOLATION]${NC} Direct modification of data files: $file"
        VIOLATIONS=$((VIOLATIONS+1))
    fi

    # Rule 2: No tampering with shared core logic
    if [[ "$file" == src/shared/* ]]; then
        echo -e "${RED}[VIOLATION]${NC} Modification of shared core logic: $file"
        VIOLATIONS=$((VIOLATIONS+1))
    fi

    # Rule 3: No tampering with workflows
    if [[ "$file" == .github/* ]]; then
        echo -e "${RED}[VIOLATION]${NC} Modification of workflows: $file"
        VIOLATIONS=$((VIOLATIONS+1))
    fi
done

# === SOFT WARNINGS (Human Error Prevention) ===

# Warning 1: File deletion detected
if [ -n "$DELETED_FILES" ]; then
    echo -e "${YELLOW}[WARNING]${NC} File deletion detected:"
    for file in $DELETED_FILES; do
        echo "          - $file"
    done
    WARNINGS=$((WARNINGS+1))
fi

# Warning 2: Check if modifying other users' files (based on commit author)
COMMITS=$(git log origin/main..HEAD --format="%H" 2>/dev/null)

for commit in $COMMITS; do
    AUTHOR=$(git log -1 --format="%ae" $commit | cut -d'@' -f1)
    FILES_IN_COMMIT=$(git diff-tree --no-commit-id --name-only -r $commit)

    for file in $FILES_IN_COMMIT; do
        # Check if file is in test/ directory
        if [[ "$file" == test/* ]]; then
            # Extract folder name (e.g., test/2026-01-20_Protocol/)
            FOLDER=$(echo "$file" | cut -d'/' -f1-2)

            # Check git blame for original author of the folder
            EXISTING_FILES=$(git ls-tree -r --name-only origin/main "$FOLDER" 2>/dev/null | head -1)
            if [ -n "$EXISTING_FILES" ]; then
                ORIGINAL_AUTHOR=$(git log --format="%ae" --diff-filter=A -- "$EXISTING_FILES" 2>/dev/null | tail -1 | cut -d'@' -f1)

                if [ -n "$ORIGINAL_AUTHOR" ] && [ "$ORIGINAL_AUTHOR" != "$AUTHOR" ]; then
                    echo -e "${YELLOW}[WARNING]${NC} $AUTHOR modifying folder created by $ORIGINAL_AUTHOR"
                    echo "          - $file"
                    WARNINGS=$((WARNINGS+1))
                fi
            fi
        fi
    done
done

# === RESULTS ===
echo ""
echo "----------------"
if [ "$VIOLATIONS" -gt 0 ]; then
    echo -e "${RED}FAILED${NC} - $VIOLATIONS violation(s)"
    echo ""
    echo "Auditors may only modify files in 'test/<Incident>/'."
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}PASSED${NC} - $WARNINGS warning(s)"
    echo ""
    echo "Review warnings before merging."
    exit 0
else
    echo -e "${GREEN}PASSED${NC}"
    exit 0
fi
