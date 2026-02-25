## **Интеграция**

#### .github/workflows/semgrep.yml for official ruleset

```yaml
name: Semgrep Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  semgrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Semgrep OWASP rules
        run: |
          docker run --rm -v "${PWD}:/src" \
            returntocorp/semgrep semgrep \
            --config=.semgrep/ \
            --junit-xml \
            --output=semgrep-results.xml \
            --severity=ERROR \
            /src
      
      - name: Upload results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: semgrep-results
          path: semgrep-results.xml
      
      - name: Fail on high severity
        run: |
          if grep -q 'severity="ERROR"' semgrep-results.xml; then
            echo "Critical vulnerabilities found!"
            exit 1
          fi
```

#### Jobs for custom ruleset

```yaml
- name: Run Semgrep Scan
  run: make scan-ci
```

***

### .pre-commit-config.yaml hook

#### For official ruleset

```yaml
repos:
  - repo: https://github.com/returntocorp/semgrep
    rev: v1.50.0
    hooks:
      - id: semgrep
        args: ['--config=.semgrep/', '--error', '--quiet']
        stages: [commit]
```
#### For custom ruleset

```bash
# .git/hooks/pre-commit
#!/bin/sh
make scan-critical || exit 1
```

***

### .semgrep/config.yml

```yaml
rules:
  - id: critical-sql-injection
    severity: ERROR
    
  - id: weak-crypto
    severity: WARNING
    
  - id: code-smell
    severity: INFO

  - id: use-secure-random
    pattern: new Random()
    fix: new SecureRandom() # autofix
    message: "Замените Random на SecureRandom для криптографических операций"
    severity: ERROR
    languages: [java]
    
    # приоритезация

  - id: sql-injection
    severity: ERROR
    meta
      priority: CRITICAL
      sla_days: 1
      
  - id: weak-crypto
    severity: WARNING
    meta
      priority: HIGH
      sla_days: 7
      
  - id: missing-javadoc
    severity: INFO
    meta
      priority: LOW
      sla_days: 30

```

***

### .semgrep/tests/test-sql-injection.yml

```bash
$ semgrep --test .semgrep/tests/ # прогонка
```

```yaml
rules:
  - id: sql-injection
    pattern: ...

tests:
  - name: Должен детектировать SQL injection
    vulnerable_code: |
      String query = "SELECT * FROM users WHERE id = " + userId;
    should_match: true
  
  - name: Не должен срабатывать на PreparedStatement
    safe_code: |
      PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
      ps.setInt(1, userId);
    should_match: false
```

***

### .semgrepignore

```gitignore
# Тесты
test/
tests/
*_test.java
*Test.java

# Сгенерированный код
target/
build/
generated/
*.g.java

# Vendor dependencies
node_modules/
vendor/

# Конкретные файлы с известными false positives
src/main/java/legacy/OldCrypto.java:weak-md5-hashing
```