#!/usr/bin/env bash
# Jira REST API helper functions
# Source this file — do not run directly.

_jira_curl() {
    curl -s \
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -H "Content-Type: application/json" \
        "$@"
}

jira_validate_token() {
    local http_status
    http_status=$(_jira_curl -o /dev/null -w "%{http_code}" "${JIRA_BASE_URL}/rest/api/3/myself")
    if [[ "$http_status" != "200" ]]; then
        echo "ERROR: Jira authentication failed (HTTP $http_status). Check ~/.config/bijoux/jira.env" >&2
        return 1
    fi
    echo "Jira authentication OK"
}

jira_add_comment() {
    local issue_key="$1"
    local comment_text="$2"
    _jira_curl \
        -X POST \
        "${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/comment" \
        -d "$(python3 -c "
import json, sys
print(json.dumps({
    'body': {
        'type': 'doc',
        'version': 1,
        'content': [{
            'type': 'paragraph',
            'content': [{
                'type': 'text',
                'text': sys.argv[1]
            }]
        }]
    }
}))
" "$comment_text")" > /dev/null
}

jira_attach_file() {
    local issue_key="$1"
    local file_path="$2"
    curl -s \
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -X POST \
        -H "X-Atlassian-Token: no-check" \
        -F "file=@${file_path}" \
        "${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/attachments" > /dev/null
}

jira_create_bug() {
    local summary="$1"
    local description="$2"
    local severity="${3:-SEV-3}"
    _jira_curl \
        -X POST \
        "${JIRA_BASE_URL}/rest/api/3/issue" \
        -d "$(python3 -c "
import json, sys
print(json.dumps({
    'fields': {
        'project': {'key': '${JIRA_PROJECT_KEY}'},
        'summary': sys.argv[1],
        'issuetype': {'id': '10091'},
        'labels': [sys.argv[3]],
        'description': {
            'type': 'doc',
            'version': 1,
            'content': [{
                'type': 'paragraph',
                'content': [{
                    'type': 'text',
                    'text': sys.argv[2]
                }]
            }]
        }
    }
}))
" "$summary" "$description" "$severity")"
}

jira_transition_to_done() {
    local issue_key="$1"
    _jira_curl \
        -X POST \
        "${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/transitions" \
        -d '{"transition":{"id":"31"}}' > /dev/null
}
