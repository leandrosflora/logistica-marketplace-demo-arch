#!/usr/bin/env bash
# Publishes synthetic order-journey events directly to Kafka so the Order Monitor
# (MarketplaceWeb /operations/orders) and OrderVisibilityService can be exercised without
# running the full saga. Requires the local docker compose stack (see
# docs/runbooks/order-visibility-local.md) with the Kafka container named
# logistica-envios-kafka, and topics already created per docs/runbooks/kafka-local-e2e.md.
#
# Usage: ./scripts/order-visibility-demo.sh <happy|inventory-failed|payment-rejected|stuck>

set -euo pipefail

KAFKA_CONTAINER="${KAFKA_CONTAINER:-logistica-envios-kafka}"
BOOTSTRAP="${BOOTSTRAP:-localhost:9092}"

new_uuid() {
    local hex
    hex=$(openssl rand -hex 16)
    echo "${hex:0:8}-${hex:8:4}-4${hex:13:3}-${hex:16:4}-${hex:20:12}"
}

now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

publish() {
    local topic="$1"
    local payload="$2"
    echo "-> ${topic}: ${payload}"
    echo "${payload}" | docker exec -i "${KAFKA_CONTAINER}" kafka-console-producer \
        --bootstrap-server "${BOOTSTRAP}" --topic "${topic}" > /dev/null
}

envelope() {
    local event_type="$1" producer="$2" correlation_id="$3" payload_json="$4"
    local event_id occurred_at
    event_id=$(new_uuid)
    occurred_at=$(now_iso)
    printf '{"eventId":"%s","eventType":"%s","schemaVersion":"1.0","occurredAt":"%s","correlationId":"%s","producer":"%s","payload":%s}' \
        "${event_id}" "${event_type}" "${occurred_at}" "${correlation_id}" "${producer}" "${payload_json}"
}

scenario="${1:-}"
if [[ -z "${scenario}" ]]; then
    echo "Usage: $0 <happy|inventory-failed|payment-rejected|stuck>" >&2
    exit 1
fi

correlation_id=$(new_uuid)
checkout_id=$(new_uuid)
order_id=$(new_uuid)
buyer_id=$(new_uuid)
seller_id=$(new_uuid)

echo "Scenario: ${scenario}"
echo "correlationId=${correlation_id} checkoutId=${checkout_id} orderId=${order_id}"

checkout_confirmed_payload=$(printf '{"checkoutId":"%s","buyerId":"%s","sellerId":"%s","currency":"BRL","shippingPrice":14.9,"shippingPromiseId":"promise_demo","paymentMethodToken":"tok_demo","items":[]}' "${checkout_id}" "${buyer_id}" "${seller_id}")
publish "checkout.confirmed" "$(envelope checkout.confirmed checkout-service "${correlation_id}" "${checkout_confirmed_payload}")"

order_created_payload=$(printf '{"orderId":"%s","checkoutId":"%s","buyerId":"%s","sellerId":"%s"}' "${order_id}" "${checkout_id}" "${buyer_id}" "${seller_id}")
publish "order.created" "$(envelope order.created order-service "${correlation_id}" "${order_created_payload}")"

case "${scenario}" in
    happy)
        publish "inventory.reserved" "$(envelope inventory.reserved inventory-service "${correlation_id}" "$(printf '{"orderId":"%s","reservationId":"%s"}' "${order_id}" "$(new_uuid)")")"
        publish "fulfillment.capacity.reserved" "$(envelope fulfillment.capacity.reserved fulfillment-center-service "${correlation_id}" "$(printf '{"orderId":"%s","reservationId":"%s"}' "${order_id}" "$(new_uuid)")")"
        publish "payment.approved" "$(envelope payment.approved payment-service "${correlation_id}" "$(printf '{"orderId":"%s","paymentAuthorizationId":"%s"}' "${order_id}" "$(new_uuid)")")"
        publish "shipment.created" "$(envelope shipment.created shipment-service "${correlation_id}" "$(printf '{"orderId":"%s","shipmentId":"%s"}' "${order_id}" "$(new_uuid)")")"
        publish "payment.captured" "$(envelope payment.captured payment-service "${correlation_id}" "$(printf '{"orderId":"%s"}' "${order_id}")")"
        publish "shipment.status.updated" "$(envelope shipment.status.updated tracking-service "${correlation_id}" "$(printf '{"orderId":"%s","currentStatus":"in_transit"}' "${order_id}")")"
        echo "Done. Journey should reach InTransit."
        ;;
    inventory-failed)
        publish "inventory.reservation.failed" "$(envelope inventory.reservation.failed inventory-service "${correlation_id}" "$(printf '{"orderId":"%s","reason":"insufficient_stock"}' "${order_id}")")"
        echo "Done. Journey should show InventoryFailed with hasError=true."
        ;;
    payment-rejected)
        publish "inventory.reserved" "$(envelope inventory.reserved inventory-service "${correlation_id}" "$(printf '{"orderId":"%s","reservationId":"%s"}' "${order_id}" "$(new_uuid)")")"
        publish "fulfillment.capacity.reserved" "$(envelope fulfillment.capacity.reserved fulfillment-center-service "${correlation_id}" "$(printf '{"orderId":"%s","reservationId":"%s"}' "${order_id}" "$(new_uuid)")")"
        publish "payment.rejected" "$(envelope payment.rejected payment-service "${correlation_id}" "$(printf '{"orderId":"%s","rejectionCode":"insufficient_funds"}' "${order_id}")")"
        echo "Done. Journey should show PaymentRejected with hasError=true."
        ;;
    stuck)
        publish "inventory.reserved" "$(envelope inventory.reserved inventory-service "${correlation_id}" "$(printf '{"orderId":"%s","reservationId":"%s"}' "${order_id}" "$(new_uuid)")")"
        echo "Done. No further events published — wait 60s+ and check GET /order-journeys/stuck or the 'Somente travados' filter."
        ;;
    *)
        echo "Unknown scenario: ${scenario}" >&2
        exit 1
        ;;
esac
