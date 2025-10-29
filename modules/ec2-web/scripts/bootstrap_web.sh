cat > modules/ec2-web/scripts/bootstrap_web.sh <<'SH'
#!/bin/bash
set -euxo pipefail

# 1) 웹서버/도구 설치
yum update -y
amazon-linux-extras install nginx1 -y
yum install -y jq awscli
systemctl enable nginx

# 2) SSM 경로(예: /apps/free-tier) - Terraform이 주입
PARAM_PATH="${PARAM_PATH_PREFIX}"

# 3) 파라미터를 JSON으로 로컬에 저장
mkdir -p /opt/app
aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --query 'Parameters[].{Name:Name,Value:Value}' \
  --output json > /opt/app/params.json

# 4) JSON -> "이름=값" 텍스트로 변환
jq -r '.[] | "\(.Name)=\(.Value)"' /opt/app/params.json > /opt/app/raw_vars.txt

# 5) 환경변수 파일 생성(한 줄씩 읽어 export 형태로 변환)
> /etc/profile.d/app_env.sh
while IFS='=' read -r full_name value; do
  name=$(basename "$full_name")                    # /apps/free-tier/app_name -> app_name
  name_upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')   # app_name -> APP_NAME
  echo "export $name_upper=\"$value\"" >> /etc/profile.d/app_env.sh  
done < /opt/app/raw_vars.txt

# 지금 쉘에도 즉시 반영
# shellcheck disable=SC1091
source /etc/profile.d/app_env.sh

# 6) 간단한 HTML 생성(환경변수 출력)
cat > /usr/share/nginx/html/index.html <<EOF
<html>
  <head><title>Free-Tier Web</title></head>
  <body>
    <h1>Hello from $APP_NAME</h1>
    <p>Environment: $APP_ENV</p>
    <p>Banner: $APP_BANNER</p>
  </body>
</html>
EOF

systemctl start nginx
SH

chmod +x modules/ec2-web/scripts/bootstrap_web.sh

