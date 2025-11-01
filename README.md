# ☁️ Terraform Free-Tier AWS Infrastructure Lab

## 📖 프로젝트 개요
이 프로젝트는 **AWS Free-Tier 한도 내에서 Terraform으로 실제 클라우드 인프라를 자동 구성**하는 DevOps 실습 프로젝트입니다.  
비용을 최소화하면서도 프로덕션 수준의 **VPC·EC2·S3·DynamoDB·IAM·Parameter Store** 설계를 IaC로 관리하는 방법을 학습합니다.

---

## 🧱 아키텍처 구성도

```mermaid
graph TD

subgraph AWS["AWS Cloud (Free-Tier)"]
  subgraph VPC["VPC (10.10.0.0/16)"]
    IGW["Internet Gateway"]
    NAT["EC2 NAT Instance"]
    WEB["EC2 Web Server"]
    S3["S3 Static Bucket"]
    DDB["DynamoDB (State Lock)"]
    PS["Parameter Store (.env)"]
  end
end

IGW --> WEB
WEB --> PS
WEB --> S3
NAT --> WEB
WEB --> DDB
```

🎯 구성 목표
- Terraform으로 완전 자동화된 인프라 프로비저닝
- Free-Tier 환경에서 NAT Gateway 없이 VPC 완전 구성
- S3 + DynamoDB를 통한 Terraform 상태 원격 관리
- Parameter Store를 통한 설정 중앙 관리
- Session Manager(SSM) 로 SSH 없이 서버 운영

📂 폴더 구조
terraform-free-tier-lab/  
├── backend.tf                  # S3+DynamoDB 백엔드 선언  
├── backend.hcl                 # Backend 설정값 (bucket, table 등)  
├── main.tf                     # 루트 모듈 연결 (VPC, EC2, IAM 등)  
├── provider.tf                 # AWS Provider, 리전/프로필 설정  
├── variables.tf                # 루트 변수 정의  
├── versions.tf                 # Terraform / AWS Provider 버전 제약  
├── terraform.tfvars            # 환경 변수 값 (예: dev, prod)  
├── bootstrap/                  # 원격 백엔드 부트스트랩 (로컬 실행)  
│   └── main.tf  
└── modules/  
    ├── vpc/                    # Step1: Free-Tier VPC 구성  
    ├── ec2-nat/                # Step2: NAT 인스턴스  
    ├── iam-ec2-ssm/            # Step3: EC2용 IAM Role/Instance Profile  
    ├── ec2-web/                # Step3: Nginx 웹 서버 자동화  
    ├── dynamodb-tfstate/       # Step4: Terraform state lock용 DDB 테이블  
    ├── s3-static/              # Step5: 정적 웹 호스팅용 (옵션)  
    └── ssm-parameter/          # Step3: SSM Parameter Store 값 관리 (옵션)  


🔑 선행 조건
- Terraform 실행은 AWS EC2 워크스테이션(Amazon Linux)에서 수행
   - EC2에 아래 IAM Role(Instance Profile) 부여:
     - ```AmazonS3FullAccess``` — tfstate 버킷 관리
     - ```AmazonDynamoDBFullAccess``` — state lock 관리
     - ```AmazonEC2FullAccess``` — EC2, VPC 리소스 생성
     - ```AmazonSSMManagedInstanceCore``` — Session Manager 접속 및 Parameter Store 접근
    
### 🎯 프로젝트 목적

AWS Free-Tier 환경에서 **비용 없이도 실제 프로덕션 구조를 재현**하며,  
Terraform IaC로 **안정적이고 재현 가능한 클라우드 인프라를 설계·자동화**하는 프로젝트입니다.

> “무료지만, 실제 서비스 수준의 아키텍처로.”  
>  
> 클라우드 설계 · 보안 · 운영 자동화의 원리를 직접 코드로 구현하고  
> DevOps 엔지니어 포트폴리오로 활용하기 위한 실습입니다.

---

### 🧱 Step 0 – Terraform 워크스테이션 설정

| 구분           | 내용                                                                                         |
| ------------ | ------------------------------------------------------------------------------------------ |
| **설명**       | 로컬 PC 대신 Amazon Linux EC2를 Terraform 개발 환경으로 사용                                            |
| **이유 (WHY)** | - 동일 리전 내에서 Terraform 실행 → 자격증명 간소화<br>- Access Key 저장 불필요 → 보안 강화<br>- 모든 구성의 재현성과 일관성 보장 |


---

### 🗂️ Step 1 – 백엔드 S3 + DynamoDB 구축

| 구분 | 내용 |
|------|------|
| **설명** | Terraform 상태(tfstate)를 S3에 저장하고, DynamoDB Lock Table로 동시 작업 충돌 방지 |
| **이유(WHY)** | - **협업 / 복구성 확보**: 로컬 tfstate 대신 중앙 저장소 관리<br>- **일관성 유지**: DynamoDB Lock으로 다중 사용자 동시 적용 방지<br>- **Free-Tier 최적화**: S3 저장 + PAY_PER_REQUEST DynamoDB로 실질 과금 없음 |

---

### 🌐 Step 2 – VPC 구성 (Public / Private Subnet)

| 구분 | 내용 |
|------|------|
| **설명** | VPC (10.10.0.0/16) 내에 퍼블릭·프라이빗 서브넷, 라우팅 테이블, IGW 구성 |
| **이유(WHY)** | - **보안 격리**: 외부 공개 자원(Web, NAT)과 내부 자원(DB, App)을 분리<br>- **비용 절감**: NAT Gateway(유료) 미사용, NAT 인스턴스 전략으로 Free-Tier 유지<br>- **네트워크 설계 학습**: CIDR 설계, AZ 분산, 라우팅 구조를 코드로 직접 구현 |
| **핵심 코드 포인트** | `map_public_ip_on_launch = true` (퍼블릭) / `false` (프라이빗) 설정으로 외부 접근 제어 |

---

### 🔒 Step 2.5 – 보안그룹 설계 (최소 개방 원칙)

| 원칙 | 설명 |
|------|------|
| **인바운드 최소화** | 서비스 포트(HTTP 80)만 허용, SSH(22)는 기본 차단 |
| **아웃바운드 허용** | 서버는 외부 업데이트 및 API 통신 필요로 전체 아웃바운드 허용 |
| **이유(WHY)** | - 공격 표면 최소화 → 기본 폐쇄형 보안 모델 적용<br>- 관리 단순화 → 운영 시 필요 포트만 한시 개방<br>- SSH는 SSM(Session Manager)로 대체하여 무SSH 운영 실현 |

---

### 🧩 Step 3 – EC2 Web Server (Nginx + SSM Parameter Store)

| 구분           | 내용                                                                                                                                                                                       |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **설명**       | EC2 인스턴스 부팅 시 user_data로 Nginx 설치 및 Parameter Store 값 반영                                                                                                                                 |
| **핵심 구성 요소** | - `modules/ec2-web/` : Nginx 설치/기동 및 index.html 생성<br>- `modules/iam-ec2-ssm/` : EC2에 IAM Role/Instance Profile 부여 (SSM 접근 허용)<br>- `modules/ssm-parameter/` : Parameter Store 값 관리 (옵션) |
| **자동화 동작**   | ① EC2 부팅 → ② user_data 실행 → ③ SSM Parameter Store에서 환경값 로드 → ④ index.html 생성 → ⑤ Nginx 시작                                                                                                |
| **결과 확인**    | `curl http://<EC2_PUBLIC_IP>` → “Hello from Terraform Web Server” 출력 성공                                                                                                                  |
| **이유 (WHY)** | - **코드 외부 구성값 관리**: 환경변수를 Parameter Store에서 주입<br>- **보안 강화**: SSH 차단 + SSM Session Manager 운영<br>- **운영 자동화**: 부팅 시 완전 자동 구성 (수동 설정 없음)                                                 |


---

### 🧠 Step별 핵심 학습 포인트
| Step | 주제      | 주요 학습 포인트                                   |
| ---- | ------- | ------------------------------------------- |
| 0    | 환경 구성   | AWS CLI, Terraform 설치, IAM Profile 인증 구조    |
| 1    | 네트워크 기초 | CIDR, Subnet, Routing, IGW 개념               |
| 2    | NAT 설계  | IP 포워딩, SNAT, 아웃바운드 라우팅                     |
| 3    | 웹 자동화   | user_data, SSM Parameter Store, IAM Role 연동 |

