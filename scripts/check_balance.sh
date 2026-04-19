#!/usr/bin/env bash
# Quick wallet/credit balance check.
# Usage: bash scripts/check_balance.sh
#
# Watches for the gift code grant to land. Current state at planning time:
#   $5 promo credit (welcome bonus, already on the wallet)
#   Awaiting: gift code request 52606d86-658f-4442-a7b7-45b60f5ea0fd (filed 2026-04-19)
#
# When approved, promo_credit_balance jumps from "5" to ~"10" (typical hackathon grant).

set -euo pipefail

cd "$(dirname "$0")/.."
source .env

curl -sS "$LOCUS_BASE_URL/api/pay/balance" \
  -H "Authorization: Bearer $LOCUS_API_KEY" | jq '{
    wallet_address,
    workspace_id,
    usdc_balance,
    promo_credit_balance,
    allowance,
    max_transaction_size
  }'
