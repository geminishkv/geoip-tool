### Команды

```bash
$ make init # Инициализировать Java правила
$ make stats # Проверить статистику правил
$ make status # Статус submodule
$ make scan # Полное сканирование
$ make scan-custom # Кастомное сканирование
$ make scan-official # Только официальные правила
$ make scan-critical # Только критичные уязвимости
$ make update-rules # Обновить правила до последней версии
$ make commit-rules # Закоммитить изменения
$ make validate # Провалидировать правила
$ make help # Помощь
$ make clean # Очистить отчеты
```

### Конфигурация

```bash
JAVA_RULES_DIR = rules/official-java-semgrep/java
CUSTOM_RULES_DIR = rules/custom
SRC_DIR = src
REPORT_DIR = reports
```

***