## **Metrics**

### Custom ruleset
```bash
$ make stats # Количество правил

# История изменений правил
$ cd rules/official-java-semgrep
$ git log --oneline -10 -- java/

$ semgrep --config rules/ src/ --json | jq '.results | group_by(.extra.severity) | map({severity: ..extra.severity, count: length})' # Количество находок по severity
```

### Official ruleset & dashbord

```python
import json
import sys

with open('report.json') as f:
    data = json.load(f)

results = data['results']
by_severity = {}
by_category = {}

for r in results:
    severity = r['extra']['severity']
    category = r['extra']['metadata'].get('owasp', 'Unknown')
    
    by_severity[severity] = by_severity.get(severity, 0) + 1
    by_category[category] = by_category.get(category, 0) + 1

print(f"📊 Semgrep Security Report")
print(f"{'='*50}")
print(f"Total issues: {len(results)}")
print(f"\nBy Severity:")
for sev, count in sorted(by_severity.items()):
    print(f"  {sev}: {count}")
print(f"\nBy OWASP Category:")
for cat, count in sorted(by_category.items(), key=lambda x: -x[1]):
    print(f"  {cat}: {count}")
```

***