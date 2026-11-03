# Журнал команд, требующих разрешения

Команды добавляются сюда **до** запроса разрешения. Можно открыть этот файл
и проверить точный запуск. Ключи, пароли и токены в журнал не записываются.
Скрипты, передаваемые по SSH, также сохраняются в `docs/commands/`.

## Ранее выполненные проверки

До создания этого журнала выполнялись `terraform validate` для bootstrap/main,
ICMP ping трёх узлов, SSH/Ansible ping под `ubuntu`, чтение состояния Kubernetes,
сборка и локальная проверка Docker-образа, HTTP-проверки приложения и Grafana.
Команды установки Kubernetes и `terraform apply` не выполнялись.

Примеры уже выполненных команд:

```bash
terraform -chdir=terraform/bootstrap validate -no-color
terraform -chdir=terraform/main validate -no-color
ping -n -c 3 -W 2 -w 8 51.250.73.47
ping -n -c 3 -W 2 -w 8 51.250.84.42
ping -n -c 3 -W 2 -w 8 51.250.87.33
curl --connect-timeout 5 --max-time 10 http://51.250.84.42:30126/
curl --connect-timeout 5 --max-time 10 -H 'Host: grafana.local' http://51.250.84.42:30126/api/health
```

Это краткое описание предыдущих проверок, а не полный исторический shell-log.
Ниже записываются точные команды новых запросов разрешения.

## 01. Проверка runner и доступов node-0

Цель: прочитать состояние runner, SSH fingerprints, доступ к Docker/Kubernetes
и сроки клиентского сертификата. Конфигурация сервера не изменяется.
Содержимое передаваемого скрипта: [inspect-node0.sh](commands/inspect-node0.sh).

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 ubuntu@51.250.73.47 'bash -s' < docs/commands/inspect-node0.sh
```

## 02. Проверка учётной записи runner и сертификатов

Цель: определить пользователя runner, доступы именно этого пользователя,
репозиторий и сроки сертификатов. Секреты не выводятся, сертификаты не обновляются.
Скрипт: [inspect-runner.sh](commands/inspect-runner.sh).

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@51.250.73.47 'bash -s' < docs/commands/inspect-runner.sh
```

## 03. Повтор проверки runner

В запуске 02 чтение `.runner` остановилось на UTF-8 BOM. Исправлено только
декодирование JSON; проверка по-прежнему не изменяет сервер.

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@51.250.73.47 'bash -s' < docs/commands/inspect-runner.sh
```

## 04. Проверка доступности GitHub-репозитория runner

Только чтение ссылки HEAD и ветки main. Никаких push или изменений GitHub.

```bash
GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/deadmorouse/diplom-netology.git HEAD refs/heads/main
```

## 05. Чтение публичных метаданных GitHub и версий Actions

Только чтение; конфигурация не изменяется.

```bash
python3 docs/commands/inspect-github.py
```

## 06. Проверка наличия Docker-авторизации и связи runner с GitHub

Только чтение; конфигурация не изменяется.

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@51.250.73.47 'bash -s' < docs/commands/inspect-runner-auth.sh
```

## 07. Повторная проверка runner и репозитория перед CI/CD

Только чтение состояния кластера, безопасных строк журнала runner и ссылок GitHub.

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@51.250.73.47 'bash -s' < docs/commands/check-cicd-access.sh
GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/deadmorouse/diplom-netology.git HEAD refs/heads/main
```

Раздел 07: SSH-запуск не получил разрешения; проверка GitHub в том же вызове не выполнялась.

## 08. Проверка после смены внешних IP

Новые адреса взяты из `ansible/prod.yaml`. `HostKeyAlias` проверяет прежний
сохранённый ключ node-0 при подключении к новому IP. Только чтение.

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=51.250.73.47 -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@62.84.125.162 'bash -s' < docs/commands/check-cicd-access.sh
```

## 09. Проверки подготовленных workflow и новых HTTP-адресов

Actionlint запускается в контейнере с проектом только для чтения. Проверка приложения
собирает локальный образ и запускает временный контейнер; ничего не публикует.
HTTP-запросы и чтение ссылок GitHub не изменяют серверы.

```bash
docker run --rm -v /home/iks/devops-netology/test-diplom/devops-netology-diplom-yc:/repo:ro -w /repo rhysd/actionlint:latest -color .github/workflows/app.yml .github/workflows/terraform.yml
python3 docs/commands/test-app-workflow.py
curl --fail --connect-timeout 5 --max-time 15 http://62.84.125.111:30126/
curl --fail --connect-timeout 5 --max-time 15 -H 'Host: grafana.local' http://62.84.125.111:30126/api/health
GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/deadmorouse/diplom-netology.git HEAD refs/heads/main
```

Результат раздела 09: приложение и Grafana отвечают по новым адресам. Репозиторий
GitHub пока пуст. Локальные Docker-проверки не запустились: Docker socket отсутствует.

## 10. Проверки без локального Docker daemon

Actionlint 1.7.12 загружается из официального release в `/tmp`, проверяется SHA256.
Smoke test выполняется на node-0 от пользователя runner во временном каталоге;
скрипт `/tmp/diploma-ci-smoke.sh` содержит копии трёх файлов testapp и команды
build/test из workflow. Созданные тестовый контейнер, образ и каталог удаляются.
Kubernetes и рабочее приложение не изменяются.

```bash
set -eu
curl -fsSL https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz -o /tmp/actionlint_1.7.12_linux_amd64.tar.gz
curl -fsSL https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_checksums.txt -o /tmp/actionlint_1.7.12_checksums.txt
cd /tmp
sha256sum --ignore-missing -c actionlint_1.7.12_checksums.txt
tar -xzf actionlint_1.7.12_linux_amd64.tar.gz actionlint
cd /home/iks/devops-netology/test-diplom/devops-netology-diplom-yc
/tmp/actionlint -color .github/workflows/app.yml .github/workflows/terraform.yml
```

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=51.250.73.47 -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@62.84.125.162 'sudo -n -H -u github-runner bash -s' < /tmp/diploma-ci-smoke.sh
```

Результат раздела 10: checksum и actionlint успешны. На node-0 прошли сборка,
`nginx -t` и сравнение HTTP-ответа с index.html. Рабочий Deployment не изменялся.

## 11. Проверка SSH-доступа к целевому GitHub-репозиторию

Только чтение Git refs с существующим SSH-ключом. Без публикации и смены remote.

```bash
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10' git ls-remote git@github.com:deadmorouse/diplom-netology.git HEAD refs/heads/main
```

Результат раздела 11: соединение остановлено до авторизации — в локальном
known_hosts нет подходящего ключа сервера github.com.

## 12. Ключи сервера GitHub из официального API и повтор чтения refs

Публичные ключи сервера берутся по HTTPS из `https://api.github.com/meta`.
Сохраняются только в `/tmp`; пользовательский known_hosts не изменяется.

```bash
python3 docs/commands/prepare-github-hostkeys.py
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-github-known-hosts -o ConnectTimeout=10' git ls-remote git@github.com:deadmorouse/diplom-netology.git HEAD refs/heads/main
```

Результат раздела 12: SSH-аутентификация GitHub успешна, целевой репозиторий пуст.

## 13. Отдельный checkout дипломного репозитория

Клонирование в `/tmp`, без изменений родительского репозитория devops-netology.

```bash
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-github-known-hosts -o ConnectTimeout=10' git clone git@github.com:deadmorouse/diplom-netology.git /tmp/diploma-publish-20261103
```

## 14. Публикация подготовленных файлов и просмотр CI

В отдельный checkout скопированы 35 файлов проекта по списку разрешённых путей:
Terraform `.tf` и lock-файлы, манифесты, приложение, inventory, workflows и документация.
Локальные `.tfvars`, state, ключи и кеши не копируются. Push создаёт main в пустом
целевом репозитории и запускает сборку приложения и Terraform validate.
Terraform apply выключен до установки `TF_AUTOMATION_ENABLED=true` и облачных secrets.

```bash
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-github-known-hosts -o ConnectTimeout=10' git -C /tmp/diploma-publish-20261103 push -u origin main
python3 docs/commands/github-actions-status.py
```

Результат раздела 14: main опубликован (commit `4b787bb`); Application CI/CD
run `41612247682` успешен, Docker Hub принял secrets. Terraform validate обоих
модулей успешен (run `41612247670`), infrastructure ожидаемо skipped.

## 15. Первый релиз приложения v1.0.0

Тег указывает на уже проверенный commit `4b787bb`. Его публикация запускает build,
push образа и обновление Deployment nginx-app в namespace test-app через runner.

```bash
git -C /tmp/diploma-publish-20261103 tag v1.0.0 4b787bb3637a6c37ebdebd6aa533f7d2b314de3a
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-github-known-hosts -o ConnectTimeout=10' git -C /tmp/diploma-publish-20261103 push origin v1.0.0
python3 docs/commands/github-actions-status.py
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=51.250.73.47 -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@62.84.125.162 'bash -s' < docs/commands/check-cicd-access.sh
curl --fail --connect-timeout 5 --max-time 15 http://62.84.125.111:30126/
```

Результат раздела 15: образ v1.0.0 опубликован; run `41612588953` остановился
в deploy на шаге Check runner and Kubernetes access, до изменения Deployment.

## 16. Диагностика первого deploy

Только выбранные строки Worker log и параметры HOME/KUBECONFIG; секреты и
полное окружение не выводятся. Скрипт: `docs/commands/inspect-deploy-failure.sh`.

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=51.250.73.47 -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@62.84.125.162 'bash -s' < docs/commands/inspect-deploy-failure.sh
```

## 17. Проверка значения digest в задании

В скрипт раздела 16 добавлен вывод публичных image digest и ближайшего значения
`DEPLOY_IMAGE`. Проверяется передача output между jobs; Kubernetes не изменяется.

```bash
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=51.250.73.47 -o UserKnownHostsFile=/tmp/diploma-ssh-check-not7380c/known_hosts-all -o ConnectTimeout=7 ubuntu@62.84.125.162 'bash -s' < docs/commands/inspect-deploy-failure.sh
```

## 18. Исправление передачи image digest и релиз v1.0.1

Полный image reference содержит DOCKERHUB_USERNAME, зарегистрированный как secret.
Теперь между jobs передаётся только sha256:hash; repository name добавляется в deploy.
Actionlint и shell-синтаксис проверены. Main и новый тег публикуются одним push;
тег запускает полный цикл сборки/теста/публикации/деплоя. Старый тег не изменяется.

```bash
git -C /tmp/diploma-publish-20261103 tag v1.0.1
GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/diploma-github-known-hosts -o ConnectTimeout=10' git -C /tmp/diploma-publish-20261103 push origin main v1.0.1
python3 docs/commands/github-actions-status.py
```

<!-- NEXT COMMAND -->
