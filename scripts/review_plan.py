"""Read terraform show -json from stdin. Never write its potentially sensitive JSON."""
import json
import sys

plan = json.load(sys.stdin)
protected = ("module.rds.", "aws_ecr_repository.ecs_app", "aws_security_group.ecs_app", "aws_security_group.alb")
errors = []
counts = {}
for resource in plan.get("resource_changes", []):
    actions = resource["change"]["actions"]
    address = resource["address"]
    if resource.get("mode") == "data":
        continue
    key = "/".join(actions)
    counts[key] = counts.get(key, 0) + 1
    if "delete" in actions:
        errors.append(f"Destructive action: {address} ({key})")
    if address.startswith(protected) and actions != ["no-op"]:
        errors.append(f"Existing protected resource changes: {address} ({key})")
print(json.dumps(counts, sort_keys=True))
for error in errors:
    print(error)
if errors:
    raise SystemExit("Review blocked: resolve unexpected changes before any apply.")
