# Дипломный проект: развёртывание Kubernetes-кластера в Yandex Cloud

## 1. Описание проекта

Проект демонстрирует развёртывание отказоустойчивой инфраструктуры и Kubernetes-кластера в Yandex Cloud с использованием:

- **Terraform** — создание облачной инфраструктуры;
- **Ansible / Kubespray** — развёртывание Kubernetes-кластера;
- **Kubernetes** — запуск тестового приложения;
- **Helm** — установка системы мониторинга;
- **Prometheus** — сбор метрик;
- **Grafana** — визуализация метрик;
- **kube-state-metrics** — метрики состояния объектов Kubernetes;
- **node-exporter** — метрики узлов Kubernetes;
- **NGINX Ingress Controller** — публикация приложений;
- **Docker** — сборка контейнерного образа тестового приложения;
- **GitHub Actions** — автоматизация CI/CD.

Итоговая схема проекта:

```text
                    Yandex Cloud
                         │
                 ┌───────▼───────┐
                 │   VPC Network │
                 │    subnet-a   │
                 └───────┬───────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
     ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
     │  node-0 │    │  node-1 │    │  node-2 │
     │ control │    │ worker   │    │ worker  │
     │  plane  │    │          │    │         │
     └────┬────┘    └────┬─────┘    └────┬────┘
          │              │               │
          └──────────────┼───────────────┘
                         │
                 Kubernetes Cluster
                         │
          ┌──────────────┴──────────────┐
          │                             │
     test-app namespace            monitoring
          │                             │
     nginx application          Prometheus/Grafana/
                                Alertmanager/exporters
```

---

# 2. Структура репозитория

```text
.
├── ansible
│   ├── prod.yaml
│   └── kubespray
│
├── k8s
│   ├── deployment.yaml
│   ├── ingress.yaml
│   ├── namespace.yaml
│   └── service.yaml
│
├── monitoring
│   └── grafana-ingress.yaml
│
├── testapp
│   ├── Dockerfile
│   ├── index.html
│   └── nginx.conf
│
├── terraform
│   ├── bootstrap
│   │   ├── bucket.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   │
│   └── main
│       ├── network.tf
│       ├── node.tf
│       ├── output.tf
│       ├── providers.tf
│       └── variables.tf
│
├── Decision.md
├── README.md
└── .gitignore
```

Каталог `ansible/kubespray` содержит исходный код Kubespray. В GitHub не требуется хранить весь исходный код Kubespray как часть проекта, если он используется как внешний проект. В репозитории достаточно хранить собственные настройки и inventory, необходимые для воспроизводимого развёртывания.

---

# 3. Этап 1. Создание инфраструктуры в Yandex Cloud

Для создания инфраструктуры используется Terraform.

## 3.1. Terraform

Основные ресурсы:

- VPC Network;
- VPC Subnet;
- три Compute Instance;
- загрузочные диски;
- сетевые интерфейсы;
- NAT для доступа к внешней сети.

Конфигурация вычислительных узлов:

```hcl
resource "yandex_compute_instance" "platform" {
  count = 3

  name        = "node-${count.index}"
  hostname    = "node-${count.index}"
  zone        = var.zone
  platform_id = "standard-v3"

  allow_stopping_for_update = true

  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image
      size     = 30
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.develop_subnet.id
    nat       = true
  }
}
```

## 3.2. Создание инфраструктуры

```bash
cd terraform/main

terraform init
terraform plan
terraform apply
```

Проверка созданных ресурсов:

```bash
terraform output
```

Пример результата:

```text
name=node-0
name=node-1
name=node-2
```

### Скриншот

Здесь добавить скриншот:

```text
docs/screenshots/01-terraform-apply.png
```

На скриншоте желательно показать успешное выполнение `terraform apply`.

---

# 4. Этап 2. Подготовка Kubernetes-узлов

После создания виртуальных машин проверяется доступ по SSH.

```bash
ssh ubuntu@<IP>
```

Проверка ОС:

```bash
hostname
ip a
```

Проверка доступности всех узлов:

```bash
ping <IP-node-1>
ping <IP-node-2>
```

---

# 5. Этап 3. Развёртывание Kubernetes через Kubespray

Для развёртывания Kubernetes используется **Kubespray**.

Kubespray автоматически выполняет настройку необходимых компонентов Kubernetes и системных параметров узлов.

## 5.1. Inventory

Используется inventory Kubespray:

```text
ansible/kubespray/inventory/mycluster/
```

В нём описываются:

- control plane;
- worker-ноды;
- параметры подключения;
- Kubernetes-компоненты.

## 5.2. Запуск Kubespray

```bash
cd ansible/kubespray

ansible-playbook \
  -i inventory/mycluster/hosts.yml \
  cluster.yml
```

После завершения проверяем кластер:

```bash
kubectl get nodes
```

Ожидаемый результат:

```text
NAME     STATUS   ROLES           AGE   VERSION
node-0   Ready    control-plane   ...   ...
node-1   Ready    <none>          ...   ...
node-2   Ready    <none>          ...   ...
```

Проверка системных Pod:

```bash
kubectl get pods -A
```

### Скриншот

```text
docs/screenshots/02-kubernetes-nodes.png
```

На скриншоте показать:

```bash
kubectl get nodes
kubectl get pods -A
```

---

# 6. Этап 4. Установка NGINX Ingress Controller

Для публикации приложений используется NGINX Ingress Controller.

Установка выполняется через Helm.

```bash
helm install ingress-nginx \
  ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace
```

Проверка:

```bash
helm list -A
```

```bash
kubectl get pods -n ingress-nginx
```

```bash
kubectl get svc -n ingress-nginx
```

После установки сервис контроллера используется для внешнего доступа к приложениям.

### Скриншот

```text
docs/screenshots/03-ingress-nginx.png
```

---

# 7. Этап 5. Развёртывание тестового приложения

Тестовое приложение находится в каталоге:

```text
testapp/
```

Структура:

```text
testapp/
├── Dockerfile
├── index.html
└── nginx.conf
```

Приложение представляет собой NGINX-контейнер.

## 7.1. Kubernetes Namespace

Создаётся namespace:

```bash
kubectl apply -f k8s/namespace.yaml
```

## 7.2. Deployment

```bash
kubectl apply -f k8s/deployment.yaml
```

## 7.3. Service

```bash
kubectl apply -f k8s/service.yaml
```

## 7.4. Ingress

```bash
kubectl apply -f k8s/ingress.yaml
```

Проверка:

```bash
kubectl get all -n test-app
```

```bash
kubectl get ingress -n test-app
```

Проверка Pod:

```bash
kubectl get pods -n test-app -o wide
```

Ожидаемый результат:

```text
nginx-app-...   1/1   Running
nginx-app-...   1/1   Running
```

### Скриншот

```text
docs/screenshots/04-test-app.png
```

---

# 8. Этап 6. Мониторинг Kubernetes

Для мониторинга Kubernetes используется Helm chart:

```text
kube-prometheus-stack
```

Он устанавливает основной набор компонентов мониторинга.

В проекте используются:

- Prometheus;
- Grafana;
- Alertmanager;
- kube-state-metrics;
- node-exporter;
- Prometheus Operator.

## 8.1. Установка мониторинга

```bash
helm install monitoring \
  prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace
```

Проверка Helm:

```bash
helm list -A
```

Пример:

```text
NAME          NAMESPACE     REVISION   STATUS
monitoring    monitoring    1          deployed
```

Проверка компонентов:

```bash
kubectl get pods -n monitoring
```

Также можно проверить сервисы:

```bash
kubectl get svc -n monitoring
```

---

# 9. Prometheus

Prometheus используется для сбора и хранения метрик.

Проверка:

```bash
kubectl get pods -n monitoring \
  -l app.kubernetes.io/name=prometheus
```

Проверка StatefulSet:

```bash
kubectl get statefulset -n monitoring
```

Prometheus получает метрики Kubernetes и узлов кластера.

---

# 10. Grafana

Grafana используется для визуализации собранных Prometheus метрик.

Проверка:

```bash
kubectl get pod -n monitoring \
  -l app.kubernetes.io/name=grafana
```

Сервис:

```bash
kubectl get svc -n monitoring monitoring-grafana
```

Grafana публикуется через Kubernetes/Ingress.

Ingress:

```bash
kubectl get ingress -n monitoring
```

Для локального доступа используется запись в `/etc/hosts`:

```text
<EXTERNAL_IP> grafana.local
```

После этого Grafana открывается по адресу:

```text
http://grafana.local
```

### Скриншот

```text
docs/screenshots/05-grafana.png
```

На скриншоте показать работающую Grafana и один из Kubernetes dashboard.

---

# 11. Alertmanager

Alertmanager используется для обработки и маршрутизации алертов Prometheus.

Проверка:

```bash
kubectl get pods -n monitoring \
  -l app.kubernetes.io/name=alertmanager
```

Проверка StatefulSet:

```bash
kubectl get statefulset -n monitoring
```

Проверка сервиса:

```bash
kubectl get svc -n monitoring | grep alertmanager
```

---

# 12. kube-state-metrics

`kube-state-metrics` предоставляет метрики состояния объектов Kubernetes:

- Pod;
- Deployment;
- Service;
- Node;
- StatefulSet;
- ReplicaSet и другие объекты Kubernetes.

Проверка:

```bash
kubectl get pods -n monitoring | grep kube-state
```

---

# 13. node-exporter

`node-exporter` используется для получения системных метрик Kubernetes-узлов.

Он работает как DaemonSet, поэтому Pod запускается на каждой ноде.

Проверка:

```bash
kubectl get daemonset -n monitoring
```

```bash
kubectl get pods -n monitoring \
  -l app.kubernetes.io/name=node-exporter
```

Ожидается по одному Pod на каждом Kubernetes-узле.

---

# 14. Helm

Установленные Helm-релизы:

```bash
helm list -A
```

Пример:

```text
NAME             NAMESPACE       STATUS
ingress-nginx    ingress-nginx   deployed
monitoring       monitoring      deployed
```

Для проверки установленных компонентов:

```bash
helm get values monitoring -n monitoring
```

В текущем варианте проекта используются **стандартные настройки Helm chart**, без отдельного `values.yaml`.

Это означает, что параметры, не изменённые в процессе установки, используются из стандартной конфигурации соответствующих Helm charts.

Получить фактически применённые настройки:

```bash
helm get values monitoring -n monitoring -o yaml
```

Полный manifest установленного релиза:

```bash
helm get manifest monitoring -n monitoring
```

---

# 15. Этап 7. Container image тестового приложения

Тестовое приложение собирается в Docker image.

Репозиторий:

```text
iksok/test-nginx-app
```

Сборка:

```bash
cd testapp

docker build -t iksok/test-nginx-app:v1 .
```

Публикация:

```bash
docker push iksok/test-nginx-app:v1
```

Проверка образа:

```bash
docker images | grep test-nginx-app
```

В Kubernetes Deployment используется образ:

```yaml
image: iksok/test-nginx-app:v1
```

---

# 16. Этап 8. CI/CD

Цель CI/CD — автоматически доставлять изменения тестового приложения в Kubernetes.

Целевой pipeline:

```text
Git push
   │
   ▼
GitHub Actions
   │
   ├── checkout
   │
   ├── docker build
   │
   ├── docker push
   │
   ├── kubectl set image
   │
   └── kubectl rollout status
           │
           ▼
      Kubernetes
           │
           ▼
      test-app
```

## 16.1. Логика версии image

Для каждого изменения кода создаётся новый image tag.

Например:

```text
iksok/test-nginx-app:v1
iksok/test-nginx-app:<commit>
```

В качестве tag можно использовать SHA коммита GitHub.

Это позволяет определить, какая версия исходного кода сейчас работает в Kubernetes.

---

# 17. GitHub Actions

Workflow размещается:

```text
.github/
└── workflows/
    └── deploy.yml
```

Основные этапы workflow:

1. получение исходного кода;
2. сборка Docker image;
3. авторизация в Docker Hub;
4. публикация image;
5. обновление Deployment;
6. ожидание успешного rollout.

Пример логики:

```yaml
docker build
docker push
kubectl set image
kubectl rollout status
```

Для выполнения Kubernetes-команд используется self-hosted GitHub Runner.

Runner установлен на control-plane ноде Kubernetes.

---

# 18. Проверка CI/CD

После изменения исходного кода:

```bash
git add .
git commit -m "update test application"
git push
```

GitHub Actions запускает workflow.

После завершения workflow проверяется Deployment:

```bash
kubectl get deployment nginx-app -n test-app
```

Проверяется используемый image:

```bash
kubectl get deployment nginx-app \
  -n test-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Проверяются Pod:

```bash
kubectl get pods -n test-app
```

Проверяется rollout:

```bash
kubectl rollout status deployment/nginx-app -n test-app
```

### Скриншоты

```text
docs/screenshots/06-github-actions.png
docs/screenshots/07-cicd-kubernetes.png
```

На первом скриншоте показать успешный workflow GitHub Actions.

На втором — изменение image и успешный rollout Kubernetes.

---

# 19. Git

Перед публикацией проекта в GitHub необходимо исключить:

- Terraform state;
- секреты;
- персональные `.tfvars`;
- SSH-ключи;
- временные файлы;
- файлы IDE;
- системные файлы.

Пример `.gitignore`:

```gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Terraform variables / secrets
*.auto.tfvars
*.tfvars

# Ansible
*.retry

# OS
.DS_Store
Thumbs.db

# Editors
.vscode/
.idea/

# Temporary files
*.tmp
*.log
```

**Важно:** `personal.auto.tfvars` и `terraform.tfstate` нельзя отправлять в публичный GitHub-репозиторий.

---

# 20. Публикация проекта в GitHub

Создание Git-репозитория:

```bash
git init
```

Добавление файлов:

```bash
git add .
```

Проверка:

```bash
git status
```

Первый commit:

```bash
git commit -m "Initial diploma project"
```

Добавление GitHub repository:

```bash
git remote add origin <GITHUB_REPOSITORY>
```

Отправка:

```bash
git branch -M main
git push -u origin main
```

---

# 21. Проверка итоговой системы

## Kubernetes

```bash
kubectl get nodes
```

```bash
kubectl get pods -A
```

## Приложение

```bash
kubectl get all -n test-app
```

```bash
kubectl get ingress -n test-app
```

## Мониторинг

```bash
kubectl get pods -n monitoring
```

```bash
kubectl get svc -n monitoring
```

## Helm

```bash
helm list -A
```

## CI/CD

Проверить последний workflow в GitHub Actions.

---

# 22. Результат проекта

В результате реализована следующая инфраструктура:

- виртуальная инфраструктура создана с помощью Terraform;
- создана VPC и подсеть в Yandex Cloud;
- развернуты три виртуальные машины;
- Kubernetes-кластер развёрнут с использованием Kubespray;
- один узел используется как control plane;
- два узла используются как worker;
- установлен NGINX Ingress Controller;
- развёрнуто тестовое NGINX-приложение;
- настроен Kubernetes Service и Ingress;
- установлен kube-prometheus-stack;
- настроены Prometheus и Grafana;
- установлен Alertmanager;
- подключены kube-state-metrics и node-exporter;
- тестовое приложение контейнеризировано;
- Docker image публикуется в Docker Hub;
- GitHub Actions используется для автоматизации CI/CD;
- после изменения исходного кода выполняется автоматическая сборка и публикация Docker image;
- Kubernetes Deployment автоматически получает новую версию приложения.

---

# 23. Скриншоты для защиты

Рекомендуемый набор скриншотов:

```text
docs/
└── screenshots/
    ├── 01-terraform-apply.png
    ├── 02-yandex-cloud-vm.png
    ├── 03-kubernetes-nodes.png
    ├── 04-kubernetes-pods.png
    ├── 05-ingress-nginx.png
    ├── 06-test-app.png
    ├── 07-grafana.png
    ├── 08-prometheus.png
    ├── 09-alertmanager.png
    ├── 10-dockerhub.png
    ├── 11-github-actions.png
    └── 12-cicd-kubernetes.png
```

Скриншоты должны подтверждать каждый основной этап:

```text
Terraform
   ↓
Yandex Cloud
   ↓
Kubespray
   ↓
Kubernetes
   ↓
Ingress
   ↓
Test Application
   ↓
Monitoring
   ↓
Docker
   ↓
GitHub Actions
   ↓
Automatic Deployment
```