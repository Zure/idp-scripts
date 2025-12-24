#!/bin/bash
set -e

echo "=== Initializing ==="
tofu init -backend-config=backend-config.tfvars

echo ""
echo "=== Planning ==="
tofu plan -out=tfplan

echo ""
read -p "Apply these changes? [y/N]: " APPLY
if [[ "$APPLY" =~ ^[Yy]$ ]]; then
    echo ""
    echo "=== Applying ==="
    tofu apply tfplan
    rm -f tfplan
    echo ""
    echo "=== Complete ==="
    tofu output
else
    echo "Cancelled"
    rm -f tfplan
fi
