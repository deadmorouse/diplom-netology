# Диплом DevOps в Yandex Cloud

[Репозиторий проекта](https://github.com/deadmorouse/diplom-netology) ·
[Docker Hub](https://hub.docker.com/r/iksok/test-nginx-app)

Terraform создаёт инфраструктуру, Kubespray устанавливает Kubernetes,
GitHub Actions собирает приложение и доставляет его в кластер.
Мониторинг реализован через Prometheus и Grafana.

В примерах `masterip`, `workip1`, `workip2` заменяются актуальными адресами из
`ansible/prod.yaml` или `terraform output`.

| Узел | Назначение | Адрес в примерах |
|---|---|---|
| node-0 | Kubernetes control plane, GitHub runner | masterip |
| node-1 | worker | workip1 |
| node-2 | worker | workip2 |

## 1. Создание инфраструктуры

Конфигурация разделена на два модуля:

- `terraform/bootstrap` — сервисный аккаунт и S3 bucket для Terraform state.
- `terraform/main` — сеть и три виртуальные машины.

Используется Terraform 1.10.1. Версии провайдеров сохранены в `.terraform.lock.hcl`.
Переменные `token`, `cloud_id`, `folder_id` задаются локально в `.tfvars`.
Для bootstrap дополнительно нужен `bucket_name=tf-backend-igor`, для main —
`public_key` с публичным SSH-ключом пользователя `ubuntu`.
Для локального запуска `token` — действующий IAM-токен, полученный через
`yc iam create-token` после авторизации CLI. В CI используется ключ сервисного аккаунта.

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan
terraform -chdir=terraform/bootstrap apply

export AWS_ACCESS_KEY_ID="$(terraform -chdir=terraform/bootstrap output -raw access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform -chdir=terraform/bootstrap output -raw secret_key)"

terraform -chdir=terraform/main init
terraform -chdir=terraform/main plan
terraform -chdir=terraform/main apply
terraform -chdir=terraform/main output
```

State основного модуля хранится в bucket `tf-backend-igor`, объект `terraform/state.tfstate`.
Локальные state, `.tfvars` и ключи не публикуются в Git.

**Скриншоты:** bucket, успешный Terraform apply и три ВМ в Yandex Cloud.
<!-- ![Backend](screenshots/01-backend.png) -->
<!-- ![Terraform](screenshots/02-terraform.png) -->
<!-- ![Виртуальные машины](screenshots/03-vm.png) -->

## 2. Ansible и Kubernetes

Развёртывание Kubernetes реализовано через **Kubespray на базе Ansible**.
Узлы проекта и подключения под пользователем `ubuntu` описаны в inventory
[`ansible/prod.yaml`](ansible/prod.yaml).

Проверка доступности узлов:

```bash
ansible -i ansible/prod.yaml all -m ping
ssh ubuntu@masterip
```

Установлены Kubernetes 1.35.3, containerd и Calico.
Проверка кластера на master под пользователем с настроенным kubeconfig:

```bash
sudo -H -u github-runner kubectl get nodes -o wide
sudo -H -u github-runner kubectl get pods -A
```

Дальнейшие команды `kubectl` и `helm` выполняются с доступом к этому кластеру.
Манифесты применяются из корня проекта.

**Скриншот:** три узла Ready и системные Pod.
<!-- ![Kubernetes](screenshots/04-kubernetes.png) -->

## 3. Тестовое приложение

В `testapp/` находятся Dockerfile, конфигурация Nginx и HTML-страница.
Приложение показывает `this is ver1.0.1`.

```bash
docker build -t iksok/test-nginx-app:v1.0.1 testapp
docker run --rm iksok/test-nginx-app:v1.0.1 nginx -t
docker run --rm -p 8080:80 iksok/test-nginx-app:v1.0.1
```

Страница доступна локально на `http://localhost:8080`.
Образы публикуются в публичный Docker Hub repository `iksok/test-nginx-app`.

**Скриншот:** Docker Hub с опубликованным тегом версии.
<!-- ![Docker Hub](screenshots/05-dockerhub.png) -->

## 4. Доступ к приложению через Ingress

Для входящего HTTP-трафика используется ingress-nginx, Helm chart 4.15.1:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version 4.15.1 -n ingress-nginx --create-namespace \
  --set controller.service.nodePorts.http=30126 \
  --set controller.service.nodePorts.https=32284
```

Первичное развёртывание приложения:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/ingress.yaml
kubectl -n test-app get deployment,pods,svc,ingress
```

Deployment `nginx-app` запускает две реплики. Ingress направляет запросы
на Service `nginx-app:80`. Последующие обновления выполняются через CI/CD.

Приложение: **http://workip1:30126**.

**Скриншоты:** ресурсы приложения и страница в браузере.
<!-- ![Ingress и приложение](screenshots/06-ingress-app.png) -->
<!-- ![Страница приложения](screenshots/07-app-browser.png) -->

## 5. Мониторинг

Используется Helm chart `kube-prometheus-stack` 86.2.2:
Prometheus, Grafana, Alertmanager, kube-state-metrics и node-exporter.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 86.2.2 -n monitoring --create-namespace
kubectl apply -f monitoring/grafana-ingress.yaml
kubectl get pods -n monitoring
```

На компьютере с браузером добавляется запись в `/etc/hosts`
(вместо `workip1` — настоящий IP worker-1):

```text
workip1 grafana.local
```

Grafana: **http://grafana.local:30126**, логин `admin`.
Получить пароль:

```bash
kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

**Скриншоты:** компоненты мониторинга и dashboard Grafana с графиками.
<!-- ![Мониторинг](screenshots/08-monitoring.png) -->
<!-- ![Grafana](screenshots/09-grafana.png) -->

## 6. CI/CD приложения

Workflow: [app.yml](.github/workflows/app.yml).

| Событие | Действия |
|---|---|
| Pull request | Сборка и проверка приложения |
| Push в ветку | Сборка, проверка, публикация образа с SHA коммита |
| Push тега `v1.0.1` | Сборка, проверка, публикация версии и деплой в Kubernetes |

Сборка выполняется на GitHub-hosted runner. Деплой — на self-hosted runner `node-0`,
который уже имеет доступ к Kubernetes. Для точного выбора собранного образа используется digest.
Версии имеют формат `vX.Y.Z`, без суффиксов.

В **Settings → Secrets and variables → Actions → Repository secrets** добавляются:

- `DOCKERHUB_USERNAME` — `iksok`.
- `DOCKERHUB_TOKEN` — Docker Hub Access Token с правом записи.

После отправки изменений в main новый релиз создаётся тегом:

```bash
git switch main
git pull --ff-only
git tag v1.0.2
git push origin v1.0.2
```

Проверка результата:

```bash
kubectl -n test-app rollout status deployment/nginx-app --timeout=180s
kubectl -n test-app get pods
curl -f http://workip1:30126/
```

**Скриншоты:** runner, успешные jobs build/deploy и обновлённая страница.
<!-- ![Runner](screenshots/10-runner.png) -->
<!-- ![GitHub Actions](screenshots/11-actions.png) -->
<!-- ![Новая версия](screenshots/12-release.png) -->

## 7. Terraform через GitHub Actions

Workflow: [terraform.yml](.github/workflows/terraform.yml).
Проверки `fmt`, `init` и `validate` уже работают. Для plan/apply добавьте секреты
в **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Откуда взять значение |
|---|---|
| `TF_STATE_ACCESS_KEY` | `terraform -chdir=terraform/bootstrap output -raw access_key` |
| `TF_STATE_SECRET_KEY` | `terraform -chdir=terraform/bootstrap output -raw secret_key` |
| `YC_SERVICE_ACCOUNT_KEY` | Полное содержимое JSON-файла авторизованного ключа сервисного аккаунта Terraform |
| `YC_CLOUD_ID` | `yc config get cloud-id` |
| `YC_FOLDER_ID` | `yc config get folder-id` |
| `VM_SSH_PUBLIC_KEY` | Содержимое текущего публичного SSH-ключа ВМ, например `~/.ssh/id_ed25519.pub` |

Команды для ключей S3 выполняются там, где сохранён state bootstrap.
Значения копируются в GitHub secrets; в репозиторий и скриншоты они не включаются.

Авторизация CI в Yandex Cloud:

1. В консоли Yandex Cloud создайте сервисный аккаунт `terraform-ci` в каталоге проекта.
2. Назначьте этому аккаунту роли на каталог: `compute.editor`, `vpc.privateAdmin`
   и `vpc.publicAdmin` для управления ВМ, сетью и внешними адресами.
3. Откройте аккаунт → **Создать новый ключ → Создать авторизованный ключ**
   и скачайте JSON-файл. Можно хранить локально в `.secrets/terraform-ci-key.json`;
   этот каталог исключён из Git.
4. Полное содержимое JSON добавьте в Repository secret `YC_SERVICE_ACCOUNT_KEY`.

Workflow сохраняет JSON во временный файл с ограниченными правами и передаёт его
провайдеру через `YC_SERVICE_ACCOUNT_KEY_FILE`. Провайдер получает IAM-токены автоматически.
Старый secret `YC_TOKEN` больше не используется; ключи S3 остаются прежними.
Аккаунт `tf-backend-sa` отвечает за S3, его роли для управления ВМ не расширяются.
[Авторизация Terraform](https://yandex.cloud/ru/docs/terraform/authentication),
[создание авторизованного ключа](https://yandex.cloud/ru/docs/iam/operations/authentication/manage-authorized-keys).

Далее:

1. В **Actions → Variables → New repository variable** создайте `TF_AUTOMATION_ENABLED`
   со значением `true`.
2. Откройте **Actions → Terraform → Run workflow**, выберите `main`.
   Ручной запуск выполнит проверки и **plan без apply**.
3. Проверьте план: он должен использовать существующий state в S3. Значения
   локальных `.tfvars`, отсутствующие в GitHub, должны совпадать с defaults проекта.
4. После успешного plan отправьте commit в main. Для проверки без изменения файлов:

   ```bash
   git commit --allow-empty -m "Verify Terraform automatic apply"
   git push origin main
   ```

5. В новом запуске откройте job `infrastructure`: шаг **Apply on main push** должен
   завершиться успешно. Если изменений нет, результат `No changes` тоже подтверждает
   успешную проверку и применение текущей конфигурации.

После включения каждый push в main запускает автоматический plan/apply основного
модуля. Bootstrap остаётся отдельным подготовительным этапом.

**Скриншот:** успешный job infrastructure с шагами plan и apply.
<!-- ![Terraform Actions](screenshots/13-terraform-actions.png) -->
