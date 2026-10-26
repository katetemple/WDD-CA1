#!/usr/bin/env bash
set -e

# Install Docker
dnf install -y docker
systemctl enable --now docker

# Write the deploy script to /usr/local/bin/deploy-wdd-ca1
cat > /usr/local/bin/deploy-wdd-ca1 <<'SCRIPT'
#!/usr/bin/env bash
# Deploys one image of the wdd-ca1 app.
# Usage: deploy-wdd-ca1 <tag>
set -euo pipefail

# Send errors to the same place as normal output, so that GitHub Actions
# shows everything in one block.
exec 2>&1

TAG="$1"
REGION=eu-west-1

# Works out the registry address from the account the instance belongs to
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
IMAGE="$REGISTRY/wdd-ca1:$TAG"

echo "Deploying $IMAGE"

# Fetches all env vars beginning with /wdd-ca1/ from the parameter store
# and copies them into a .env file called wdd-ca1.env
aws ssm get-parameters-by-path \
  --region "$REGION" \
  --path /wdd-ca1/ \
  --with-decryption \
  --query 'Parameters[].[Name,Value]' \
  --output text \
  | sed 's|^/wdd-ca1/||' \
  | tr '\t' '=' > /etc/wdd-ca1.env

# Sets permissions for file owner only to have access to .env file
chmod 600 /etc/wdd-ca1.env

# Login to ECR to pull wdd-ca1 app containers
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker pull "$IMAGE"

# Replace the running container with one from the new image
docker rm -f wdd-ca1 || true
docker run -d \
  --name wdd-ca1 \
  --restart unless-stopped \
  -p 80:8000 \
  --env-file /etc/wdd-ca1.env \
  "$IMAGE"

# Delete images that no container is using, so old versions don't fill the disk
docker image prune -af

echo "Deployed $IMAGE"
SCRIPT

chmod +x /usr/local/bin/deploy-wdd-ca1

# Start the newest image
/usr/local/bin/deploy-wdd-ca1 latest