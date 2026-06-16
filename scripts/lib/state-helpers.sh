#!/usr/bin/env bash
# State management for cross-layer E2E testing.
# Writes/reads results/state.json to pass entity IDs between layers.
#
# Usage:
#   source scripts/lib/state-helpers.sh
#   state_init
#   state_set "bookings[0].id" "abc-123"
#   state_set "bookings[0].parent" "Sarah"
#   VALUE=$(state_get "bookings[0].id")

STATE_FILE="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/results/state.json"

state_init() {
  mkdir -p "$(dirname "$STATE_FILE")"
  cat > "$STATE_FILE" <<'INIT'
{"bookings":[],"sessions":[],"users":{},"cancellations":[],"metadata":{"created":"","layer1_script":""}}
INIT
  python3 -c "
import json, datetime
with open('$STATE_FILE') as f: d = json.load(f)
d['metadata']['created'] = datetime.datetime.now().isoformat()
with open('$STATE_FILE', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null
}

state_set() {
  local path="$1" value="$2"
  python3 -c "
import json, sys
path = '$path'
value = '$value'
with open('$STATE_FILE') as f: data = json.load(f)

# Navigate path like 'bookings[0].id' or 'users.sarah.id'
parts = []
for p in path.replace(']', '').split('.'):
    if '[' in p:
        name, idx = p.split('[')
        parts.append(name)
        parts.append(int(idx))
    else:
        parts.append(p)

obj = data
for i, part in enumerate(parts[:-1]):
    next_part = parts[i + 1]
    if isinstance(part, int):
        while len(obj) <= part:
            obj.append({})
        obj = obj[part]
    else:
        if part not in obj:
            obj[part] = [] if isinstance(next_part, int) else {}
        obj = obj[part]

last = parts[-1]
if isinstance(last, int):
    while len(obj) <= last:
        obj.append({})
    obj[last] = value
else:
    obj[last] = value

with open('$STATE_FILE', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null
}

state_get() {
  local path="$1"
  python3 -c "
import json
path = '$path'
with open('$STATE_FILE') as f: data = json.load(f)
parts = []
for p in path.replace(']', '').split('.'):
    if '[' in p:
        name, idx = p.split('[')
        parts.append(name)
        parts.append(int(idx))
    else:
        parts.append(p)
obj = data
for part in parts:
    if isinstance(part, int):
        obj = obj[part] if part < len(obj) else ''
    else:
        obj = obj.get(part, '')
    if obj == '': break
print(obj if obj else '')
" 2>/dev/null
}

state_append_booking() {
  local id="$1" parent="$2" caregiver="$3" lifecycle="$4"
  python3 -c "
import json
with open('$STATE_FILE') as f: data = json.load(f)
data['bookings'].append({
    'id': '$id', 'parent': '$parent',
    'caregiver': '$caregiver', 'lifecycle': '$lifecycle'
})
with open('$STATE_FILE', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null
}

state_append_session() {
  local id="$1" booking_id="$2" status="$3"
  python3 -c "
import json
with open('$STATE_FILE') as f: data = json.load(f)
data['sessions'].append({
    'id': '$id', 'bookingId': '$booking_id', 'status': '$status'
})
with open('$STATE_FILE', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null
}

state_set_user() {
  local key="$1" id="$2" role="$3"
  python3 -c "
import json
with open('$STATE_FILE') as f: data = json.load(f)
data['users']['$key'] = {'id': '$id', 'role': '$role'}
with open('$STATE_FILE', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null
}

state_append_cancellation() {
  local booking_id="$1" reason="$2"
  python3 -c "
import json
with open('$STATE_FILE') as f: data = json.load(f)
data.setdefault('cancellations', []).append({
    'bookingId': '$booking_id', 'reason': '$reason'
})
with open('$STATE_FILE', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null
}
