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
