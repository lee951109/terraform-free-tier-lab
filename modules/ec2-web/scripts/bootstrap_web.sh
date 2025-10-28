#!/bin/bash
# --------------------------------------------------
# EC2 UserData Script (Web Server Initialization)
# --------------------------------------------------
# Purpose:
#   - Install Nginx
#   - Fetch SSM Parameter Store values
#   - Generate environment variables file
#   - Render index.html dynamically
# --------------------------------------------------

set -euxo pipefail

yum update -y
amazon-linux-extras install nginx1 -y
yum install -y jq awscli

systemctl enable nginx

# ---------- Parameter Store에서 값 읽기 ----------
# 이 값은 Terraform templatefile()이 주입합니다.
PARAM_PATH="${PARAM_PATH_PREFIX}"
mkdir -p /opt/app

aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --query 'Parameters[].{Name:Name,Value:Value}' \
  --output json > /opt/app/params.json

# ---------- 환경파일 생성 ----------
echo "# generated from SSM ${PARAM_PATH}" > /etc/profile.d/app_env.sh
for row in $(jq -c '.[]' /opt/app/params.json); do
  NAME=$(echo "$row" | jq -r '.Name' | awk -F'/' '{print toupper($NF)}')
  VAL=$(echo "$row" | jq -r '.Value')
  echo "export ${NAME}=\"${VAL}\"" >> /etc/profile.d/app_env.sh
done
chmod 644 /etc/profile.d/app_env.sh
# 로그인 셸 외에도 바로 활용하려면 현재 세션에 반영
source /etc/profile.d/app_env.sh

# ---------- Nginx 페이지 렌더링 ----------
# 주의: 아래 $${...}는 Terraform이 렌더링 후' ${...}'로 남겨,
#       셸에서 런타임에 환경변수로 확장되게 합니다.
cat >/usr/share/nginx/html/index.html <<HTML
<html>
  <head><title>Free-Tier Web</title></head>
  <body>
    <h1>Hello from $${APP_NAME}</h1>
    <p>Environment: $${APP_ENV}</p>
    <p>Banner: $${APP_BANNER}</p>
  </body>
</html>
HTML

systemctl start nginx

# ---------- 파라미터 재적용용 스크립트 ----------
cat >/usr/local/bin/fetch-params.sh <<'SH'
#!/bin/bash
set -euxo pipefail

# 주의: 여기서는 템플릿 엔진이 아니라 셸만 해석합니다(quoted heredoc).
#       따라서 이 파일 안에서도 $${...}가 아니라 ${...}로 써도 됩니다.
PARAM_PATH="$${PARAM_PATH_PREFIX:-$${PARAM_PATH}}"

aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --query 'Parameters[].{Name:Name,Value:Value}' \
  --output json > /opt/app/params.json

echo "# regenerated from SSM ${PARAM_PATH}" > /etc/profile.d/app_env.sh
for row in $(jq -c '.[]' /opt/app/params.json); do
  NAME=$(echo "$row" | jq -r '.Name' | awk -F'/' '{print toupper($NF)}')
  VAL=$(echo "$row" | jq -r '.Value')
  echo "export ${NAME}=\"${VAL}\"" >> /etc/profile.d/app_env.sh
done
chmod 644 /etc/profile.d/app_env.sh
source /etc/profile.d/app_env.sh

cat >/usr/share/nginx/html/index.html <<EOF
<html>
  <head><title>Free-Tier Web</title></head>
  <body>
    <h1>Hello from ${APP_NAME}</h1>
    <p>Environment: ${APP_ENV}</p>
    <p>Banner: ${APP_BANNER}</p>
  </body>
</html>
EOF

systemctl reload nginx
SH

chmod +x /usr/local/bin/fetch-params.sh

