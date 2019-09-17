#!/bin/sh -l
# Env vars:
#	SNYK_ACTION_WRAP_LINES		Number of lines to wrap

set -eux

echo "WAZZZZUUUUUUUUUUUUUUUUUUUUUUUUUUUUP"

SNYK_ACTION_WRAP_LINES_DEFAULT=10

# wrap takes some output and wraps it in a collapsible markdown section if
# it's over $SNYK_ACTION_WRAP_LINES long.
wrap() {
  if [[ $(echo "$1" | wc -l) -gt ${SNYK_ACTION_WRAP_LINES:-$SNYK_ACTION_WRAP_LINES_DEFAULT} ]]; then
    echo "
<details><summary>Show Output</summary>
\`\`\`
$1
\`\`\`
</details>
"
else
    echo "
\`\`\`
$1
\`\`\`
"
fi
}


# Install all the requirements
if [ -f $2 ] ; then
	# If file specified, try getting requirements.txt from its directory
	findfrom=`dirname $2`
else
	# Otherwise install from all requirements.txt in target path
	findfrom=$2
fi
find $findfrom -name requirements.txt -exec bash -c 'pip install -r {}' \;

# For running snyk - don't exit immediately on "failure"
set +e
OUTPUT=$(sh -c "snyk $*" 2>&1)
SUCCESS=$?
echo "$OUTPUT"
set -e

# If PR_DATA is null, then this is not a pull request event and so there's nowhere to comment
PR_DATA=$(cat /github/workflow/event.json | jq -r .pull_request)
if [ "$PR_DATA" = "null" ]; then
    exit $SUCCESS
fi


# Build the comment we'll post to the PR
COMMENT=""
if [ $SUCCESS -ne 0 ]; then
    OUTPUT=$(wrap "$OUTPUT")
    COMMENT="#### \`SNYK\` Failed
$OUTPUT
*Workflow: \`$GITHUB_WORKFLOW\`, Action: \`$GITHUB_ACTION\`*"
else
    # Call wrap to optionally wrap our output in a collapsible markdown section.
    OUTPUT=$(wrap "$OUTPUT")
    COMMENT="#### \`SNYK\` Success
$OUTPUT
*Workflow: \`$GITHUB_WORKFLOW\`, Action: \`$GITHUB_ACTION\`*"
fi


# Post the comment
PAYLOAD=$(echo '{}' | jq --arg body "$COMMENT" '.body = $body')
echo "RDKLS"
cat /github/workflow/event.json
COMMENTS_URL=$(cat /github/workflow/event.json | jq -r .pull_request.comments_url)
if [ "$COMMENTS_URL" != 'null' ] ; then curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/json" --data "$PAYLOAD" "$COMMENTS_URL" > /dev/null ; fi


exit $SUCCESS
