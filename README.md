# ☁️ Terraform Free-Tier AWS Infrastructure Lab

## 📖 프로젝트 개요

이 프로젝트는 **AWS Free-Tier 한도 내에서 Terraform을 사용하여 완전한 클라우드 인프라를 자동 구성**하는 실습용 DevOps 프로젝트입니다.  
비용을 발생시키지 않으면서도, 실제 프로덕션 수준의 인프라 설계 및 IaC(Terraform) 관리 방법을 학습하기 위함입니다.

---

## 🧱 아키텍처 구성도

```mermaid
graph TD

subgraph AWS["AWS Cloud (Free-Tier)"]
  subgraph VPC["VPC (10.0.0.0/16)"]
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

| 구성요소                   | 설명                            | Free-Tier 유지 전략   |
| ---------------------- | ----------------------------- | ----------------- |
| **VPC**                | 1개 Public + 1개 Private Subnet | CIDR 최소화 (/28)    |
| **EC2 (Web)**          | Public Subnet에 배포             | `t3.micro` 사용     |
| **EC2 (NAT Instance)** | Private Subnet의 NAT 역할        | NAT Gateway 미사용   |
| **S3 (Static)**        | 정적 자산 및 tfstate 저장            | Versioning 비활성    |
| **DynamoDB**           | Terraform state lock 테이블      | PAY_PER_REQUEST   |
| **Parameter Store**    | 환경 변수 관리                      | 표준(Standard) Tier |
| **IAM Role**           | Terraform 실행용 권한              | 최소권한 원칙 적용        |

주요 기술 스택
| 구분                 | 기술                                                      |
| ------------------ | ------------------------------------------------------- |
| **IaC 도구**         | Terraform `>= 1.8.0`                                    |
| **Cloud Provider** | AWS Free-Tier (VPC, EC2, S3, DynamoDB, Parameter Store) |
| **State Backend**  | S3 + DynamoDB                                           |
| **OS / 런타임 환경**    | Amazon Linux / EC2 Instance                             |
| **버전 관리**          | Git / GitHub                                            |
| **다이어그램 작성**       | Mermaid (Markdown 렌더링용)                                 |

IAM Role 구성
| 정책 이름                          | 설명                                     |
| ------------------------------ | -------------------------------------- |
| `AmazonS3FullAccess`           | S3 버킷(tfstate, static asset 등) 접근      |
| `AmazonDynamoDBFullAccess`     | Terraform state lock 테이블 접근            |
| `AmazonSSMManagedInstanceCore` | Session Manager 접속, Parameter Store 접근  |
| `AmazonEC2FullAccess`          | EC2(vpc) 접근                               |



# Terraform Free-Tier Lab (VPC + NAT Instance, S3/DynamoDB Backend)

> **목표**  
> - 한 대의 EC2(개발 워크스테이션)에서 Terraform/Git 작업  
> - S3 + DynamoDB로 원격 상태 관리  
> - **NAT Gateway 없이** Free-Tier 친화 VPC 구성 (퍼블릭/프라이빗 서브넷, 라우팅)  
> - 이후 NAT **인스턴스**로 프라이빗 아웃바운드 인터넷 연결 제공

---

## 폴더 구조
terraform-free-tier-lab/  
├─ backend.tf # S3+DynamoDB 백엔드 정의(실제 값은 backend.hcl)  
├─ main.tf # 루트: VPC 호출 (+ NAT 모듈 연결부)  
├─ provider.tf # 기본 리전  
├─ variables.tf # 루트 변수  
├─ versions.tf # 버전 정책  
├─ terraform.tfvars # (예시) 환경별 값  
├─ backend.hcl # ← 커밋 금지(.gitignore) / terraform init -backend-config=backend.hcl  
├─ .gitignore  
├─ bootstrap/ # 백엔드(S3/DDB) 부트스트랩 (로컬 상태)  
│ └─ main.tf  
└─ modules/ 
├─ vpc/ # Free-Tier VPC (NAT GW 없음)  
│ ├─ main.tf  
│ ├─ variables.tf   
│ └─ outputs.tf  
└─ ec2-nat/ # NAT 인스턴스 모듈  
├─ main.tf  
├─ variables.tf  
└─ outputs.tf  

---

## 선행 조건
- 워크스테이션 EC2에 **IAM Role(Instance Profile)** 연결  
  - 최소: S3/DynamoDB(tfstate), VPC/EC2/라우팅 생성 권한  
- `backend.hcl` (커밋 금지) 예시:
  ```hcl
  bucket         = "free-tier-lab-tfstate-<unique>"
  key            = "dev/terraform.tfstate"
  region         = "ap-northeast-2"
  dynamodb_table = "tfstate-lock"
  encrypt        = true


# 최초 또는 백엔드 재구성 시
terraform init -backend-config=backend.hcl -reconfigure

# 계획/적용
terraform plan  
terraform apply -auto-approve  


