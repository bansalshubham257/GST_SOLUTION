#!/usr/bin/env bash
# Quick user creation script for Railway PostgreSQL.
# Usage: ./scripts/create-user.sh
#
# Make sure you have psql installed and the DATABASE_URL available.

set -e

echo "=== Create a New User Account ==="
echo ""

read -rp "Username: " USERNAME
read -rsp "Password: " PASSWORD
echo ""
read -rp "Full Name: " NAME
read -rp "Phone: " PHONE

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Username and password are required."
  exit 1
fi

# Generate bcrypt hash using node
HASH=$(node -e "console.log(require('bcryptjs').hashSync('$PASSWORD', 10))")

# Insert into database
PGPASSWORD='LZjgyzthYpacmWhOSAnDMnMWxkntEEqe' psql \
  -h switchback.proxy.rlwy.net \
  -U postgres \
  -p 22297 \
  -d railway \
  -c "INSERT INTO gst_app.users (username, password_hash, name, phone, plan_type, max_staff, max_services, max_sales)
      VALUES ('$USERNAME', '$HASH', '${NAME:-''}', '${PHONE:-''}', 'free', 2, 2, 2)
      RETURNING id, username, name, plan_type, max_staff, max_services, max_sales;"

echo ""
echo "=== User Created! Share these credentials: ==="
echo "  Username: $USERNAME"
echo "  Password: $PASSWORD"
echo "  Plan: Free (2 staff, 2 services, 2 sales)"
echo ""
