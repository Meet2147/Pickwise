#!/usr/bin/env bash
# Adds Yearly ($49.99/yr) and Lifetime ($149 one-time) Pickwise Pro plans,
# attaches the existing license-key benefit to both, and creates ONE checkout
# link offering all three plans. Run it yourself; prompts for a Polar org token.
set -euo pipefail
API="https://api.polar.sh/v1"
BENEFIT_ID="${BENEFIT_ID:-a8473003-4276-4bfe-8478-3ab186311b6e}"   # existing Pickwise Pro key benefit

if [ -z "${POLAR_TOKEN:-}" ]; then read -r -s -p "Polar organization token: " POLAR_TOKEN; echo; fi
auth=(-H "Authorization: Bearer $POLAR_TOKEN" -H "Content-Type: application/json")
die(){ echo "✗ $*" >&2; exit 1; }
post(){ curl -sS -X POST "${auth[@]}" "$API/$1" -d "$2"; }
jid(){ python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])'; }

echo "1/5 Finding the existing monthly product…"
LIST=$(curl -sS "${auth[@]}" "$API/products/?is_archived=false&limit=50")
MONTHLY_ID=$(echo "$LIST" | python3 -c '
import json,sys
d=json.load(sys.stdin)
if "items" not in d:
    sys.stderr.write("Polar said: %s\n" % json.dumps(d)); sys.exit(0)
for p in d["items"]:
    if p.get("recurring_interval")=="month" and "Pickwise" in p["name"]:
        print(p["id"]); break')
[ -n "$MONTHLY_ID" ] || die "Couldn't find the monthly product. Polar response above — if it mentions scopes or authentication, recreate the token with products:read, products:write, benefits:write, checkout_links:write."
echo "   monthly: $MONTHLY_ID"

echo '2/5 Creating Pickwise Pro Yearly ($49.99/year)…'
YEARLY=$(post "products/" '{
  "name": "Pickwise Pro — Yearly",
  "description": "30 AI product comparisons a month in the Pickwise Mac app. Two months free vs monthly. Cancel anytime.",
  "recurring_interval": "year",
  "prices": [ { "amount_type": "fixed", "price_currency": "usd", "price_amount": 4999 } ]
}')
YEARLY_ID=$(echo "$YEARLY" | jid) || die "yearly failed: $YEARLY"
echo "   yearly: $YEARLY_ID"

echo '3/5 Creating Pickwise Pro Lifetime ($149 once)…'
LIFETIME=$(post "products/" '{
  "name": "Pickwise Pro — Lifetime",
  "description": "30 AI product comparisons a month in the Pickwise Mac app. Pay once, keep it forever.",
  "prices": [ { "amount_type": "fixed", "price_currency": "usd", "price_amount": 14900 } ]
}')
LIFETIME_ID=$(echo "$LIFETIME" | jid) || die "lifetime failed: $LIFETIME"
echo "   lifetime: $LIFETIME_ID"

echo "4/5 Attaching the license-key benefit to both…"
for PID in "$YEARLY_ID" "$LIFETIME_ID"; do
  ATTACH=$(post "products/$PID/benefits" '{ "benefits": ["'$BENEFIT_ID'"] }')
  echo "$ATTACH" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert any(b["id"]=="'$BENEFIT_ID'" for b in d["benefits"])' || die "attach failed for $PID: $ATTACH"
done
echo "   attached."

echo "5/5 Creating combined checkout link (monthly + yearly + lifetime)…"
LINK=$(post "checkout-links/" '{
  "payment_processor": "stripe",
  "products": ["'$MONTHLY_ID'", "'$YEARLY_ID'", "'$LIFETIME_ID'"],
  "label": "Pickwise Pro (all plans)",
  "success_url": "https://pickwise.dashovia.app/?welcome=pro"
}')
URL=$(echo "$LINK" | python3 -c 'import json,sys;print(json.load(sys.stdin)["url"])') || die "checkout link failed: $LINK"
echo
echo "✓ Done. Paste this checkout URL back into the chat:"
echo "  $URL"
echo "(Remember to revoke this token in Polar afterwards.)"
