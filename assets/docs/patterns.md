## **Правила**

### Добавление правила

```bash
$ vi/vim/nano rules/custom/my-custom-rule.yml # Создать файл правила
$ make validate # Проверить валидность
```

### Паттерн правил

```yaml
rules:
  - id: my-custom-sqli
    languages: [java]
    severity: CRITICAL
    message: Potential SQL Injection detected
    pattern: |
      $STMT.executeQuery("SELECT * FROM users WHERE id = " + $VAR)
    meta
      owasp: ["A03:2024-Injection"]
      cwe: ["CWE-89"]
```

### Cheatsheet

```yaml
pattern: $X.execute($QUERY) # Простое совпадение
pattern-either: [...] # Логическое ИЛИ
pattern-not: ... # Исключение
patterns: [...] # Логическое И
pattern-inside: ... # Внутри контекста
metavariable-pattern: ... # Фильтр по метапеременной
metavariable-comparison: ... # Сравнение значений

# Метапеременные
$X, $Y, $Z # Одиночное выражение
$...ARGS # Список аргументов
$... # Любой код

# Тип сопоставления
mode: taint # Taint-анализ
```

***