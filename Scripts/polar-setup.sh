#!/usr/bin/env bash
# One-time Polar setup for Pickwise Pro: benefit -> product -> attach -> checkout link.
# Run it yourself; it prompts for your Polar organization token (never stored).
set -euo pipefail
# org is implied by the organization token
API="https://api.polar.sh/v1"

if [ -z "${POLAR_TOKEN:-}" ]; then read -r -s -p "Polar organization token: " POLAR_TOKEN; echo; fi
auth=(-H "Authorization: Bearer $POLAR_TOKEN" -H "Content-Type: application/json")
die(){ echo "✗ $*" >&2; exit 1; }
post(){ curl -sS -X POST "${auth[@]}" "$API/$1" -d "$2"; }

if [ -n "${BENEFIT_ID:-}" ]; then
  echo "1/4 Reusing existing benefit $BENEFIT_ID"
else
echo "1/4 Creating license-key benefit…"
BENEFIT=$(post "benefits/" '{
  "type": "license_keys",
  "description": "Pickwise Pro subscription key",
  "properties": { "prefix": "PICKWISE", "activations": { "limit": 3, "enable_customer_admin": true } }
}')
BENEFIT_ID=$(echo "$BENEFIT" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])') || die "benefit failed: $BENEFIT"
echo "   benefit: $BENEFIT_ID"
fi

echo '2/4 Creating product Pickwise Pro ($5.99/month)…'
PRODUCT=$(post "products/" '{
  "name": "Pickwise Pro",
  "description": "50 AI product comparisons a month in the Pickwise Mac app. Cancel anytime.",
  "recurring_interval": "month",
  "prices": [ { "amount_type": "fixed", "price_currency": "usd", "price_amount": 599 } ]
}')
PRODUCT_ID=$(echo "$PRODUCT" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])') || die "product failed: $PRODUCT"
echo "   product: $PRODUCT_ID"

echo "3/4 Attaching benefit to product…"
ATTACH=$(post "products/$PRODUCT_ID/benefits" '{ "benefits": ["'$BENEFIT_ID'"] }')
echo "$ATTACH" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert any(b["id"]=="'$BENEFIT_ID'" for b in d["benefits"])' || die "attach failed: $ATTACH"
echo "   attached."

echo "4/4 Creating checkout link…"
LINK=$(post "checkout-links/" '{
  "payment_processor": "stripe",
  "product_id": "'$PRODUCT_ID'",
  "label": "Pickwise Pro",
  "success_url": "https://pickwise-m7az.onrender.com/?welcome=pro"
}')
URL=$(echo "$LINK" | python3 -c 'import json,sys;print(json.load(sys.stdin)["url"])') || die "checkout link failed: $LINK"
echo
echo "✓ Done. Paste this checkout URL back into the chat:"
echo "  $URL"
