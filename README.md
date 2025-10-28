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
- EC2(개발 워크스테이션) 한 대에서 Terraform/Git 작업 수행
- S3 + DynamoDB로 원격 상태 관리 (tfstate + state lock)
- NAT Gateway 없이 Free-Tier로 유지 가능한 VPC 설계
- 퍼블릭/프라이빗 서브넷 및 라우팅 구조 학습
- NAT 인스턴스를 이용한 프라이빗 아웃바운드 연결 구성

📂 폴더 구조
terraform-free-tier-lab/  
├─ backend.tf                  # S3+DynamoDB 백엔드 정의(backend.hcl에서 로드)  
├─ main.tf                     # 루트: VPC 모듈 호출 + NAT 모듈 연결  
├─ provider.tf                 # 기본 리전  
├─ variables.tf                # 루트 변수 정의   
├─ versions.tf                 # Terraform/AWS Provider 버전 정책  
├─ terraform.tfvars            # (예시) 환경별 값  
├─ backend.hcl                 # ← 커밋 금지(.gitignore)  
├─ .gitignore  
├─ bootstrap/                  # 백엔드(S3/DDB) 부트스트랩 (로컬 상태)  
│  └─ main.tf  
└─ modules/  
   ├─ vpc/                     # Free-Tier VPC (NAT GW 없음)  
   │  ├─ main.tf  
   │  ├─ variables.tf  
   │  └─ outputs.tf  
   └─ ec2-nat/                 # NAT 인스턴스 모듈  
      ├─ main.tf  
      ├─ variables.tf  
      └─ outputs.tf  

🔑 선행 조건
- 워크스테이션 EC2에 IAM Role(Instance Profile) 연결
   - 최소 권한:
     - AmazonS3FullAccess (tfstate 버킷)
     - AmazonDynamoDBFullAccess (state lock)
     - AmazonEC2FullAccess (VPC/서브넷/라우팅 생성)
     - AmazonSSMManagedInstanceCore (SSM 접속 및 Parameter Store)
    
### 🎯 프로젝트 목적

AWS Free-Tier 환경에서 **비용 없이도 실제 프로덕션 구조를 재현**하며,  
Terraform IaC로 **안정적이고 재현 가능한 클라우드 인프라를 설계·자동화**하는 프로젝트입니다.

> “무료지만, 실제 서비스 수준의 아키텍처로.”  
>  
> 클라우드 설계 · 보안 · 운영 자동화의 원리를 직접 코드로 구현하고  
> DevOps 엔지니어 포트폴리오로 활용하기 위한 실습입니다.

---

### 🧱 Step 0 – Terraform 환경 구성 (EC2 Workstation)

| 구분 | 내용 |
|------|------|
| **설명** | Windows → AWS EC2(Amazon Linux) 원격 접속 후, 해당 EC2를 Terraform 개발 워크스테이션으로 구성 |
| **이유(WHY)** | - 동일 AWS 네트워크 내에서 Terraform 명령을 실행하여 자격 증명과 접근 제어 간소화<br>- Access Key 파일 저장 불필요 → 보안 강화<br>- 모든 설정이 일관된 환경에서 반복 가능 → IaC 환경에 적합 |

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

### 🧩 Step 3 – NAT Instance + Web Server 모듈

| 구성 요소 | 설명 |
|------------|------|
| **NAT Instance** | 퍼블릭 서브넷에 EC2 배치 → IP 포워딩 + iptables MASQUERADE 설정으로 프라이빗 서브넷 아웃바운드 트래픽 처리 |
| **Web Server (Nginx)** | 퍼블릭 서브넷 EC2 → user_data 스크립트로 자동 설치, 부팅 즉시 웹 페이지 응답 |
| **라우팅 구조** | - Public RT: `0.0.0.0/0 → IGW` (양방향 인터넷 연결)<br>- Private RT: `0.0.0.0/0 → NAT ENI` (아웃바운드 전용 연결) |
| **이유(WHY)** | - **Free-Tier 비용 절감**: NAT Gateway 대신 t3.micro 인스턴스 활용<br>- **학습 가치**: L3 포워딩, SNAT 개념을 직접 실습<br>- **자동화 원칙**: user_data로 수동 SSH 없이 부팅 시 자동 구성(Nginx 설치, index.html 생성) |
| **결과** | 브라우저에서 `http://<web_public_ip>` 접속 시 → “Hello from Terraform Web Server” 출력 확인 성공 |

---
