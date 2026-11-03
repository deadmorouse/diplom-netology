# Диплом DevOps: Kubernetes в Yandex Cloud

Репозиторий: [deadmorouse/diplom-netology](https://github.com/deadmorouse/diplom-netology).
Образ приложения: `iksok/test-nginx-app` в Docker Hub.
Исходное задание: [docs/ASSIGNMENT.md](docs/ASSIGNMENT.md).

## 1. Архитектура и состояние стенда

```text
Terraform → Yandex Cloud: VPC, подсеть, 3 ВМ
                          └─ Kubernetes (Kubespray, containerd, Calico)
Интернет → NodePort 30126 → ingress-nginx → nginx-app (2 реплики)
                                        └─ Grafana (Host: grafana.local)
GitHub push → hosted runner → build → HTTP test → Docker Hub
GitHub tag v1.0.0 → проверки → Docker Hub → runner node-0 → Kubernetes
```

Проверено 3 ноября 2026 года: три узла `Ready`, приложение — `2/2`,
служба runner активна, подключена к GitHub и имеет доступ к Kubernetes.
Workflow подготовлены; успешный запуск из GitHub Actions ещё требуется подтвердить.

| Узел | Роль | Внешний IP из inventory | Внутренний IP при обследовании |
|---|---|---|---|
| node-0 | control plane, etcd, GitHub runner | 62.84.125.162 | 10.0.1.12 |
| node-1 | worker | 62.84.125.111 | 10.0.1.13 |
| node-2 | worker | 62.84.126.188 | 10.0.1.25 |

SSH: `ubuntu`, вход по ключу. Внешние адреса динамические: после остановки ВМ
сверяйте `terraform output` и [ansible/prod.yaml](ansible/prod.yaml).

Установленные версии: Ubuntu 22.04.5, Kubernetes 1.35.3, containerd 2.2.2,
Calico 3.30.7 (VXLAN). Helm charts: ingress-nginx 4.15.1 и kube-prometheus-stack 86.2.2.

## 2. Структура проекта

| Путь | Назначение |
|---|---|
| `terraform/bootstrap/` | Сервисный аккаунт, статический ключ и bucket для state |
| `terraform/main/` | Сеть, подсеть и три ВМ |
| `ansible/prod.yaml` | Inventory для проверки SSH/Ansible |
| `testapp/` | Dockerfile, nginx.conf, index.html |
| `k8s/` | Namespace, Deployment, Service, Ingress приложения |
| `monitoring/grafana-ingress.yaml` | Публикация Grafana |
| `.github/workflows/app.yml` | Сборка, проверка, публикация и деплой приложения |
| `.github/workflows/terraform.yml` | Проверки Terraform, plan и apply |
| `docs/COMMANDS.md` | Журнал команд, требующих разрешения |
| `screenshots/` | Скриншоты отчёта |

Далее шаги описаны в порядке создания стенда. На работающем стенде используйте
команды проверки; повторная установка нужна только при восстановлении.
Добавляйте скриншоты под соответствующими шагами, раскомментировав Markdown-ссылки.

## 3. Terraform: backend и инфраструктура

Локально использовался Terraform 1.10.1. Версии провайдеров закреплены в
`.terraform.lock.hcl`. State, ключи и локальные `.tfvars` в Git не включаются.

Для `terraform/bootstrap` задайте `token`, `cloud_id`, `folder_id`,
`bucket_name=tf-backend-igor` в локальном `.tfvars` или переменных `TF_VAR_*`.

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan
terraform -chdir=terraform/bootstrap apply
```

Создаётся аккаунт `tf-backend-sa` с ролью `storage.editor` для S3.
Он не получает права управления ВМ. Авторизация провайдера для работы с
инфраструктурой задаётся отдельно переменной `token`.

Ключи backend передаются через окружение:

```bash
export AWS_ACCESS_KEY_ID="$(terraform -chdir=terraform/bootstrap output -raw access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform -chdir=terraform/bootstrap output -raw secret_key)"
```

Основной модуль использует bucket `tf-backend-igor`, ключ `terraform/state.tfstate`.
Для него нужны `token`, `cloud_id`, `folder_id`, `public_key` — содержимое публичного
SSH-ключа пользователя `ubuntu`. При смене bucket обновите backend в providers.tf.

```bash
terraform -chdir=terraform/main init
terraform -chdir=terraform/main plan
terraform -chdir=terraform/main apply
terraform -chdir=terraform/main output
```

Создаются три прерываемые ВМ `standard-v3`: 4 vCPU, 4 GB RAM, доля CPU 20%,
диск 30 GB. Текущая подсеть — `10.0.1.0/24`, зона `ru-central1-a`.

**Скриншот 01:** созданный bucket в Object Storage, без ключей доступа.
<!-- ![Backend](screenshots/01-backend.png) -->
Файл: `screenshots/01-backend.png`.

**Скриншот 02:** успешный `terraform apply` и `terraform output`.
<!-- ![Terraform](screenshots/02-terraform.png) -->
Файл: `screenshots/02-terraform.png`.

**Скриншот 03:** три ВМ в консоли Yandex Cloud с именами и адресами.
<!-- ![Виртуальные машины](screenshots/03-vm.png) -->
Файл: `screenshots/03-vm.png`.

## 4. Доступ к узлам и Kubernetes

```bash
ansible -i ansible/prod.yaml all -m ping
ssh ubuntu@62.84.125.162
```

Кластер установлен через Kubespray, commit
`65352fef396a4ddd319682e74acb3bb208ba8ff7`.
Использованный checkout найден в соседнем проекте:
`../devops-netology-diplom-yc-main/ansible/kubespray`.
Inventory: `inventory/mycluster/hosts.yml`, настройки: `inventory/mycluster/group_vars/`.
Внешние адреса этого inventory требуют актуализации перед повторным запуском.

Команда установки из каталога **этого Kubespray checkout**:

```bash
ansible-playbook -i inventory/mycluster/hosts.yml -u ubuntu -b cluster.yml
```

`ansible/prod.yaml` — обычный inventory для проверки доступа, он не заменяет
inventory Kubespray. Старый `k8s-cluster.yaml` удалён. Обёртки Kubespray в проект
не включены. Повторная установка требует сохранённого внешнего checkout с настройками.

На node-0 уже настроен kubeconfig пользователя runner:

```bash
sudo -H -u github-runner kubectl get nodes -o wide
sudo -H -u github-runner kubectl get pods -A
```

Для дальнейших команд `kubectl` и `helm` нужен доступ к API кластера.
В SSH-сессии `ubuntu` можно использовать установленный административный kubeconfig:

```bash
sudo -i
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes
kubectl get pods -A
```

Манифесты ниже применяются из корня checkout проекта на машине с доступом к API.

**Скриншот 04:** `kubectl get nodes -o wide` и системные Pod в состоянии Running.
<!-- ![Kubernetes](screenshots/04-kubernetes.png) -->
Файл: `screenshots/04-kubernetes.png`.

## 5. Приложение и Docker Hub

Nginx отдаёт `testapp/index.html` на порту 80. Базовый образ — `nginx:1.28-alpine`.

```bash
docker build -t iksok/test-nginx-app:local testapp
docker run --rm iksok/test-nginx-app:local nginx -t
docker run --rm -p 8080:80 iksok/test-nginx-app:local
```

В другом терминале: `curl -f http://localhost:8080/`.
До первого CI/CD-релиза на стенде работает `iksok/test-nginx-app:v1`.
Репозиторий образов должен быть публичным для скачивания узлами без `imagePullSecret`.

**Скриншот 05:** Docker Hub, репозиторий `iksok/test-nginx-app` и опубликованные теги.
<!-- ![Docker Hub](screenshots/05-dockerhub.png) -->
Файл: `screenshots/05-dockerhub.png`.

## 6. Ingress и публикация приложения

На стенде установлен release `ingress-nginx`, chart 4.15.1.
Для новой установки команда закрепляет используемые NodePort:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version 4.15.1 --namespace ingress-nginx --create-namespace \
  --set controller.service.nodePorts.http=30126 \
  --set controller.service.nodePorts.https=32284
kubectl get svc -n ingress-nginx
```

Тип сервиса — `LoadBalancer`; внешний балансировщик не подключён, поэтому
`EXTERNAL-IP` остаётся `pending`. Для HTTP используется NodePort 30126.

Первичная установка приложения:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/ingress.yaml
kubectl -n test-app rollout status deployment/nginx-app --timeout=180s
kubectl -n test-app get deployment,pods,svc,ingress -o wide
curl -f http://62.84.125.111:30126/
```

Ingress `test-nginx` направляет запросы на **Service `nginx-app:80`**.
Deployment запускает две реплики с меткой `app: nginx-app`.
После перехода на CI/CD новые версии доставляются через release tags;
повторный apply статического deployment.yaml вернёт образ `v1`.

**Скриншот 06:** Service контроллера с NodePort и две реплики приложения.
<!-- ![Ingress и приложение](screenshots/06-ingress-app.png) -->
Файл: `screenshots/06-ingress-app.png`.

**Скриншот 07:** страница приложения в браузере с адресной строкой.
<!-- ![Приложение](screenshots/07-app-browser.png) -->
Файл: `screenshots/07-app-browser.png`.

## 7. Мониторинг

Release `monitoring`, chart `kube-prometheus-stack` 86.2.2 включает Prometheus,
Grafana, Alertmanager, Prometheus Operator, kube-state-metrics и node-exporter.
Базовая установка нового стенда:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 86.2.2 --namespace monitoring --create-namespace
kubectl apply -f monitoring/grafana-ingress.yaml
```

Проверка фактической установки и её пользовательских настроек:

```bash
helm list -A
helm get values monitoring -n monitoring
helm get values ingress-nginx -n ingress-nginx
kubectl get pods,svc -n monitoring
kubectl get daemonset -n monitoring
```

Отдельный экспорт пользовательских Helm values пока не сохранён в проекте.
Перед восстановлением учитывайте вывод `helm get values`.

На компьютере с браузером добавьте в hosts:

```text
62.84.125.111 grafana.local
```

Grafana: **http://grafana.local:30126**. Логин `admin`, пароль из Secret:

```bash
kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

Пароль не включается в отчёт. Проверка маршрута:

```bash
curl -f -H 'Host: grafana.local' http://62.84.125.111:30126/api/health
```

**Скриншот 08:** Pod мониторинга и DaemonSet node-exporter на трёх узлах.
<!-- ![Мониторинг](screenshots/08-monitoring.png) -->
Файл: `screenshots/08-monitoring.png`.

**Скриншот 09:** Grafana, Kubernetes dashboard с непустыми графиками CPU/памяти.
<!-- ![Grafana](screenshots/09-grafana.png) -->
Файл: `screenshots/09-grafana.png`.

## 8. GitHub Actions: приложение

Workflow: [.github/workflows/app.yml](.github/workflows/app.yml).

| Событие | Результат |
|---|---|
| Pull request | Сборка, `nginx -t`, HTTP-проверка содержимого страницы |
| Push в ветку | Проверки и публикация `sha-<полный SHA коммита>` |
| Push тега `v1.0.0` / `v1.0.0-rc.1` | Проверки, публикация SHA и version tag, деплой |
| Run workflow | Только сборка и проверки, без публикации и деплоя |

Сборка выполняется на GitHub-hosted `ubuntu-24.04`. Релизный commit должен входить
в историю `main`. Job `deploy` выполняется на self-hosted runner `node-0` под
пользователем `github-runner`, устанавливает проверенный образ по digest и ждёт rollout.
При ошибке выводит состояние Pod и события namespace. Деплои сериализуются
группой concurrency `deploy-test-app`.

### Настройки и доступы

В `deadmorouse/diplom-netology`: **Settings → Secrets and variables → Actions →
Repository secrets**.

| Secret | Значение |
|---|---|
| `DOCKERHUB_USERNAME` | `iksok` |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token с правом записи |

Владелец добавил оба секрета. Их работоспособность подтверждается первым запуском.
Environment secrets не используются.

Runner зарегистрирован для этого репозитория. Служба:
`actions.runner.deadmorouse-diplom-netology.node-0.service`.
Каталог: `/home/github-runner/actions-runner`.
В **Settings → Actions → Runners** ожидаются статус `Idle` и метки
`self-hosted`, `Linux`, `X64`.

```bash
sudo systemctl status actions.runner.deadmorouse-diplom-netology.node-0.service
sudo -H -u github-runner kubectl get nodes
sudo -H -u github-runner kubectl auth can-i patch deployments -n test-app
```

Kubeconfig уже настроен у `github-runner`; передавать его через GitHub secret не нужно.
Проверенный клиентский сертификат действует до 8 апреля 2027 года, 23:05 UTC.
Смена внешнего IP не требует перерегистрации runner, если сохранены исходящий
доступ к GitHub и внутренний доступ к API кластера.

### Запуск и проверка

После публикации файлов в `main` дождитесь успешного `Application CI/CD`
во вкладке Actions. В Docker Hub появится тег `sha-…`.
Затем из checkout **именно `deadmorouse/diplom-netology`**:

```bash
git switch main
git pull --ff-only
git tag v1.0.0
git push origin v1.0.0
```

Для следующего релиза используйте новый тег, например `v1.0.1`.
После завершения `deploy`:

```bash
kubectl -n test-app rollout status deployment/nginx-app --timeout=180s
kubectl -n test-app get deployment nginx-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n test-app rollout history deployment/nginx-app
curl -f http://62.84.125.111:30126/
```

Image должен иметь вид `iksok/test-nginx-app@sha256:…` и совпадать с выводом job `build`.
Для демонстрации обновления измените HTML, отправьте commit и создайте новый version tag.

**Скриншот 10:** runner `node-0` со статусом `Idle`.
<!-- ![Runner](screenshots/10-runner.png) -->
Файл: `screenshots/10-runner.png`.

**Скриншот 11:** успешный workflow release tag, jobs `build` и `deploy`.
<!-- ![GitHub Actions](screenshots/11-actions.png) -->
Файл: `screenshots/11-actions.png`.

**Скриншот 12:** новый digest в Deployment, успешный rollout и обновлённая страница.
<!-- ![Релиз](screenshots/12-release.png) -->
Файл: `screenshots/12-release.png`.

## 9. GitHub Actions: Terraform

Workflow: [.github/workflows/terraform.yml](.github/workflows/terraform.yml).
Оба модуля проходят `fmt`, `init -backend=false`, `validate` без облачных секретов.
Автоматизация основной инфраструктуры включается после настройки доступа к существующему state.

Дополнительные Repository secrets:

| Secret | Назначение |
|---|---|
| `TF_STATE_ACCESS_KEY` | Статический access key аккаунта S3 |
| `TF_STATE_SECRET_KEY` | Соответствующий secret key |
| `YC_TOKEN` | Действующий токен Yandex Cloud для провайдера |
| `YC_CLOUD_ID` | ID облака |
| `YC_FOLDER_ID` | ID каталога |
| `VM_SSH_PUBLIC_KEY` | Текущий публичный SSH-ключ ВМ одной строкой |

В **Actions → Variables** добавьте Repository variable `TF_AUTOMATION_ENABLED=true`.
Выполните **Actions → Terraform → Run workflow** на `main`: ручной запуск делает
только plan. Сверьте, что используется существующий state и план не предлагает
неожиданного пересоздания работающего стенда.

Последующие push в `main` запускают plan и apply сохранённого плана.
Настройки `zone`, `cidr`, `ubuntu_image` берутся из defaults кода: локальные `.tfvars`
в GitHub не попадают. Их отличия нужно перенести в несекретную конфигурацию до включения.
Bootstrap автоматически не применяется. План удаляется в конце job, в artifacts не выгружается.
Concurrency исключает параллельные запуски этого job; параллельный локальный apply
следует исключить отдельно.

**Скриншот 13:** успешные Terraform validation, plan и apply в GitHub Actions.
<!-- ![Terraform Actions](screenshots/13-terraform-actions.png) -->
Файл: `screenshots/13-terraform-actions.png`.

## 10. Что осталось подтвердить перед сдачей

- Опубликовать workflow в целевом репозитории, подтвердить сборку, публикацию и
  релизный деплой в Actions; добавить скриншоты.
- Настроить отдельные секреты Terraform и подтвердить автоматический apply.
- В задании указаны подсети в разных зонах. Текущий Terraform создаёт одну подсеть
  в одной зоне; это расхождение ещё не устранено.
- Inventory Kubespray находится вне репозитория. Для автономного воспроизведения
  его вместе с настройками потребуется включить в сдаваемые материалы.
- Один control plane и один etcd — стенд не отказоустойчивый; все ВМ прерываемые.

Этот README — актуальное описание. `Decision.md` сохранён как прежний черновик
и может содержать устаревшие пути и заявления о ещё не проверенных этапах.

## 11. Команды и справка

Команды с запросом разрешения заранее записываются в [docs/COMMANDS.md](docs/COMMANDS.md),
диагностические скрипты — в `docs/commands/`. Исторические записи сохраняют
адреса, действовавшие на момент проверки.

- [Checkout action](https://github.com/actions/checkout)
- [Terraform setup action](https://github.com/hashicorp/setup-terraform)
- [Проверка self-hosted runner](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/monitor-and-troubleshoot)
