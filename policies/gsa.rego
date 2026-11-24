package main

import rego.v1

projects := {"dev": "alvarorg14-demo-dev", "pre": "alvarorg14-demo-pre", "pro": "alvarorg14-demo-pro"}
roles := {"roles/logging.logWriter", "roles/monitoring.metricWriter"}
allowed_types := {"google_service_account", "google_project_iam_member"}
actions := [["create"], ["update"], ["delete"], ["delete", "create"], ["create", "delete"], ["no-op"]]

valid_id(id) if {
    is_string(id)
    count(id) >= 6
    count(id) <= 30
    regex.match(`^demo-[a-z][a-z0-9-]*-(dev|pre|pro)$`, id)
}

valid_pair(id, project) if {
    valid_id(id)
    some env, expected in projects
    endswith(id, sprintf("-%s", [env]))
    project == expected
}

valid_principal(member, project) if {
    is_string(member)
    parts := split(member, "@")
    count(parts) == 2
    startswith(parts[0], "serviceAccount:")
    id := trim_prefix(parts[0], "serviceAccount:")
    parts[1] == sprintf("%s.iam.gserviceaccount.com", [project])
    valid_pair(id, project)
}

# A missing resource_changes is normal for an empty Terraform plan. If present,
# it must be an array; malformed entries must not produce an allow decision.
deny contains "resource_changes must be an array" if {
    not is_array(object.get(input, "resource_changes", []))
}

deny contains "plan must be an object" if { not is_object(input) }

deny contains msg if {
    some r in object.get(input, "resource_changes", [])
    not is_object(r)
    msg := "malformed resource change"
}

deny contains msg if {
    some r in object.get(input, "resource_changes", [])
    is_object(r)
    not object.get(r, "mode", "") in {"managed", "data"}
    msg := sprintf("%s: missing or invalid resource mode", [object.get(r, "address", "unknown")])
}

deny contains msg if {
    some r in object.get(input, "resource_changes", [])
    r.mode == "managed"
    change := object.get(r, "change", {})
    not object.get(change, "actions", null) in actions
    msg := sprintf("%s: missing or unsupported actions", [object.get(r, "address", "unknown")])
}

deny contains msg if {
    some r in object.get(input, "resource_changes", [])
    some action in object.get(object.get(r, "change", {}), "actions", [])
    action == "delete"
    msg := sprintf("%s: deletion and replacement are forbidden", [object.get(r, "address", "unknown")])
}

deny contains msg if {
    some r in object.get(input, "resource_changes", [])
    r.mode == "managed"
    r.change.actions != ["no-op"]
    not object.get(r, "type", "") in allowed_types
    msg := sprintf("%s: resource type %s is not allowed", [object.get(r, "address", "unknown"), object.get(r, "type", "unknown")])
}

deny contains msg if {
    some r in object.get(input, "resource_changes", [])
    r.mode == "managed"
    r.type == "google_service_account"
    r.change.actions in [["create"], ["update"]]
    after := object.get(r.change, "after", {})
    unknown := object.get(r.change, "after_unknown", {})
    not valid_gsa(after, unknown)
    msg := sprintf("%s: account ID or project is invalid, missing or unknown", [object.get(r, "address", "unknown")])
}

valid_gsa(after, unknown) if {
    is_object(after)
    is_object(unknown)
    object.get(unknown, "account_id", false) == false
    object.get(unknown, "project", false) == false
    valid_pair(object.get(after, "account_id", null), object.get(after, "project", null))
}

deny contains msg if {
    some r in object.get(input, "resource_changes", [])
    r.mode == "managed"
    r.type == "google_project_iam_member"
    r.change.actions in [["create"], ["update"]]
    after := object.get(r.change, "after", {})
    unknown := object.get(r.change, "after_unknown", {})
    not valid_iam(after, unknown)
    msg := sprintf("%s: role, project or service-account principal is forbidden, missing or unknown", [object.get(r, "address", "unknown")])
}

valid_iam(after, unknown) if {
    is_object(after)
    is_object(unknown)
    every key in ["role", "project", "member"] { object.get(unknown, key, false) == false }
    object.get(after, "role", null) in roles
    valid_principal(object.get(after, "member", null), object.get(after, "project", null))
}
