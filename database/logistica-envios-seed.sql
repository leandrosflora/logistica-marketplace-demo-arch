BEGIN;

INSERT INTO product_catalog.products (
    sku_id, title, category, weight_kg, height_cm, width_cm, length_cm, status
) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Smartphone Mercado Livre Demo', 'electronics', 0.450, 8.00, 16.00, 22.00, 'active'),
    ('11111111-1111-1111-1111-111111111112', 'Fone Bluetooth Demo', 'electronics', 0.120, 5.00, 10.00, 12.00, 'active')
ON CONFLICT (sku_id) DO NOTHING;

INSERT INTO product_catalog.product_restrictions (sku_id, restriction_code) VALUES
    ('11111111-1111-1111-1111-111111111111', 'fragile'),
    ('11111111-1111-1111-1111-111111111112', 'battery_lithium')
ON CONFLICT (sku_id, restriction_code) DO NOTHING;

INSERT INTO product_search.product_index (
    sku_id, seller_id, title, category, price, thumbnail_url, available_quantity, searchable_text
) VALUES
    (
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'Smartphone Mercado Livre Demo',
        'electronics',
        1299.90,
        'https://example.com/products/smartphone-demo.jpg',
        25,
        'smartphone mercado livre demo electronics celular'
    ),
    (
        '11111111-1111-1111-1111-111111111112',
        '22222222-2222-2222-2222-222222222222',
        'Fone Bluetooth Demo',
        'electronics',
        129.90,
        'https://example.com/products/fone-demo.jpg',
        80,
        'fone bluetooth demo electronics audio'
    )
ON CONFLICT (sku_id, seller_id) DO NOTHING;

INSERT INTO fulfillment.fulfillment_centers (
    fulfillment_center_id, code, name, status, zip_code, city, state, country, daily_cutoff, timezone
) VALUES
    (
        '33333333-3333-3333-3333-333333333333',
        'FC-SP-01',
        'Fulfillment Center Sao Paulo 01',
        'active',
        '05700-000',
        'Sao Paulo',
        'SP',
        'BR',
        '14:00:00',
        'America/Sao_Paulo'
    )
ON CONFLICT (fulfillment_center_id) DO NOTHING;

INSERT INTO fulfillment.capacity_windows (
    capacity_window_id, fulfillment_center_id, starts_at, ends_at, total_capacity, reserved_capacity, confirmed_capacity
) VALUES
    (
        '33333333-3333-3333-3333-333333333334',
        '33333333-3333-3333-3333-333333333333',
        '2026-06-22 08:00:00-03',
        '2026-06-22 18:00:00-03',
        1000,
        1,
        0
    )
ON CONFLICT (capacity_window_id) DO NOTHING;

INSERT INTO fulfillment.capacity_reservations (
    reservation_id, capacity_window_id, order_id, quantity, status, idempotency_key, expires_at
) VALUES
    (
        '33333333-3333-3333-3333-333333333335',
        '33333333-3333-3333-3333-333333333334',
        '66666666-6666-6666-6666-666666666666',
        1,
        'confirmed',
        '33333333-3333-3333-3333-333333333336',
        '2026-06-22 18:00:00-03'
    )
ON CONFLICT (reservation_id) DO NOTHING;

INSERT INTO inventory.inventory_balances (
    inventory_balance_id, sku_id, seller_id, fulfillment_center_id, total_quantity, reserved_quantity
) VALUES
    (
        '44444444-4444-4444-4444-444444444441',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        25,
        1
    ),
    (
        '44444444-4444-4444-4444-444444444442',
        '11111111-1111-1111-1111-111111111112',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        80,
        0
    )
ON CONFLICT (sku_id, seller_id, fulfillment_center_id) DO NOTHING;

INSERT INTO inventory.inventory_reservations (
    reservation_id, order_id, checkout_id, status, idempotency_key, expires_at, confirmed_at
) VALUES
    (
        '44444444-4444-4444-4444-444444444443',
        '66666666-6666-6666-6666-666666666666',
        '55555555-5555-5555-5555-555555555555',
        'confirmed',
        '44444444-4444-4444-4444-444444444444',
        '2026-06-22 18:00:00-03',
        '2026-06-22 10:02:00-03'
    )
ON CONFLICT (reservation_id) DO NOTHING;

INSERT INTO inventory.inventory_reservation_items (
    reservation_item_id, reservation_id, sku_id, seller_id, fulfillment_center_id, quantity
) VALUES
    (
        '44444444-4444-4444-4444-444444444445',
        '44444444-4444-4444-4444-444444444443',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        1
    )
ON CONFLICT (reservation_item_id) DO NOTHING;

INSERT INTO inventory.inventory_adjustments (
    adjustment_id, sku_id, seller_id, fulfillment_center_id, quantity_delta, reason, created_by
) VALUES
    (
        '44444444-4444-4444-4444-444444444446',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        25,
        'initial_seed',
        'seed-script'
    )
ON CONFLICT (adjustment_id) DO NOTHING;

INSERT INTO routing.network_nodes (
    node_id, code, node_type, name, zip_code, city, state, country, status
) VALUES
    (
        '33333333-3333-3333-3333-333333333333',
        'FC-SP-01',
        'fulfillment_center',
        'Fulfillment Center Sao Paulo 01',
        '05700-000',
        'Sao Paulo',
        'SP',
        'BR',
        'active'
    ),
    (
        '77777777-7777-7777-7777-777777777771',
        'HUB-SP-CENTRO',
        'hub',
        'Hub Sao Paulo Centro',
        '01000-000',
        'Sao Paulo',
        'SP',
        'BR',
        'active'
    ),
    (
        '77777777-7777-7777-7777-777777777772',
        'LM-SP-ZS',
        'last_mile',
        'Last Mile Sao Paulo Zona Sul',
        '01310-100',
        'Sao Paulo',
        'SP',
        'BR',
        'active'
    )
ON CONFLICT (node_id) DO NOTHING;

INSERT INTO routing.network_lanes (
    lane_id, origin_node_id, destination_node_id, corridor, distance_km, status
) VALUES
    (
        '77777777-7777-7777-7777-777777777773',
        '33333333-3333-3333-3333-333333333333',
        '77777777-7777-7777-7777-777777777771',
        'SP-SP',
        18.50,
        'active'
    ),
    (
        '77777777-7777-7777-7777-777777777774',
        '77777777-7777-7777-7777-777777777771',
        '77777777-7777-7777-7777-777777777772',
        'SP-SP',
        9.30,
        'active'
    )
ON CONFLICT (origin_node_id, destination_node_id) DO NOTHING;

INSERT INTO routing.routes (
    route_id, origin_node_id, destination_zip_code, mode, service_level_code, sla_days, corridor, valid_from
) VALUES
    (
        'route_sp_same_day_01310100',
        '33333333-3333-3333-3333-333333333333',
        '01310-100',
        'same_day',
        'same_day',
        0,
        'SP-SP',
        '2026-06-22 00:00:00-03'
    )
ON CONFLICT (route_id) DO NOTHING;

INSERT INTO routing.route_hubs (route_id, sequence_number, node_id) VALUES
    ('route_sp_same_day_01310100', 1, '77777777-7777-7777-7777-777777777771'),
    ('route_sp_same_day_01310100', 2, '77777777-7777-7777-7777-777777777772')
ON CONFLICT (route_id, sequence_number) DO NOTHING;

INSERT INTO carrier.carriers (
    carrier_code, name, status, integration_type
) VALUES
    ('carrier_1', 'Carrier Demo Express', 'active', 'api'),
    ('correios', 'Correios', 'active', 'api')
ON CONFLICT (carrier_code) DO NOTHING;

INSERT INTO carrier.service_levels (
    carrier_code, service_level_code, name, min_sla_days, max_sla_days, status
) VALUES
    ('carrier_1', 'same_day', 'Entrega no mesmo dia', 0, 0, 'active'),
    ('carrier_1', 'standard', 'Entrega padrao', 3, 7, 'active'),
    ('correios', 'standard', 'PAC Demo', 3, 7, 'active')
ON CONFLICT (carrier_code, service_level_code) DO NOTHING;

INSERT INTO carrier.carrier_restrictions (
    restriction_id, carrier_code, restriction_type, restriction_value, active
) VALUES
    (
        '88888888-8888-8888-8888-888888888881',
        'correios',
        'product_restriction',
        'battery_lithium',
        true
    )
ON CONFLICT (restriction_id) DO NOTHING;

INSERT INTO pricing.subsidy_rules (
    subsidy_rule_id, seller_id, category, promotion_code, subsidy_type, subsidy_value, starts_at, ends_at, active
) VALUES
    (
        '99999999-9999-9999-9999-999999999991',
        '22222222-2222-2222-2222-222222222222',
        'electronics',
        'FREE_SAME_DAY_DEMO',
        'fixed_amount',
        5.00,
        '2026-06-01 00:00:00-03',
        '2026-12-31 23:59:59-03',
        true
    )
ON CONFLICT (subsidy_rule_id) DO NOTHING;

INSERT INTO pricing.freight_prices (
    freight_price_id, route_id, carrier_code, service_level_code, package_hash,
    gross_cost, subsidy_amount, buyer_cost, currency, calculated_at
) VALUES
    (
        '99999999-9999-9999-9999-999999999992',
        'route_sp_same_day_01310100',
        'carrier_1',
        'same_day',
        'pkg-smartphone-0450kg',
        19.90,
        5.00,
        14.90,
        'BRL',
        '2026-06-22 10:00:00-03'
    )
ON CONFLICT (freight_price_id) DO NOTHING;

INSERT INTO checkout.checkouts (
    checkout_id, buyer_id, seller_id, status, shipping_promise_id, total_amount,
    currency, destination, correlation_id, expires_at, confirmed_at, created_at, updated_at
) VALUES
    (
        '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'confirmed',
        'promise_123',
        1299.90,
        'BRL',
        '{"street":"Av. Paulista","number":"1000","city":"Sao Paulo","state":"SP","zipCode":"01310-100","country":"BR"}',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '2026-06-22 18:00:00-03',
        '2026-06-22 10:01:00-03',
        '2026-06-22 10:00:00-03',
        '2026-06-22 10:01:00-03'
    )
ON CONFLICT (checkout_id) DO NOTHING;

INSERT INTO checkout.checkout_items (
    checkout_item_id, checkout_id, sku_id, seller_id, quantity, unit_price
) VALUES
    (
        '55555555-5555-5555-5555-555555555556',
        '55555555-5555-5555-5555-555555555555',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        1,
        1299.90
    )
ON CONFLICT (checkout_item_id) DO NOTHING;

INSERT INTO shipping_promise.shipping_promises (
    promise_id, checkout_id, buyer_id, seller_id, mode, carrier_code, route_id,
    service_level_code, origin_node_id, estimated_delivery_date, cost, currency,
    source, status, request_payload, result_payload, correlation_id, created_at
) VALUES
    (
        'promise_123',
        '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'same_day',
        'carrier_1',
        'route_sp_same_day_01310100',
        'same_day',
        '33333333-3333-3333-3333-333333333333',
        '2026-06-22',
        14.90,
        'BRL',
        'calculated',
        'calculated',
        '{"checkoutId":"55555555-5555-5555-5555-555555555555"}',
        '{"available":true,"mode":"same_day","carrier":"carrier_1"}',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '2026-06-22 10:00:20-03'
    )
ON CONFLICT (promise_id) DO NOTHING;

INSERT INTO checkout.shipping_promise_projections (
    promise_id, checkout_id, buyer_id, seller_id, mode, carrier_code,
    estimated_delivery_date, cost, currency, source, payload, received_at
) VALUES
    (
        'promise_123',
        '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'same_day',
        'carrier_1',
        '2026-06-22',
        14.90,
        'BRL',
        'calculated',
        '{"promiseId":"promise_123","source":"calculated"}',
        '2026-06-22 10:00:25-03'
    )
ON CONFLICT (promise_id) DO NOTHING;

INSERT INTO order_domain.orders (
    order_id, checkout_id, buyer_id, seller_id, shipping_promise_id, route_id,
    carrier_code, service_level_code, origin_node_id, promised_delivery_date,
    destination, status, total_amount, currency, correlation_id, created_at, updated_at
) VALUES
    (
        '66666666-6666-6666-6666-666666666666',
        '55555555-5555-5555-5555-555555555555',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'promise_123',
        'route_sp_same_day_01310100',
        'carrier_1',
        'same_day',
        '33333333-3333-3333-3333-333333333333',
        '2026-06-22',
        '{"street":"Av. Paulista","number":"1000","city":"Sao Paulo","state":"SP","zipCode":"01310-100","country":"BR"}',
        'confirmed',
        1299.90,
        'BRL',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '2026-06-22 10:01:30-03',
        '2026-06-22 10:05:00-03'
    )
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO order_domain.order_items (
    order_item_id, order_id, sku_id, quantity, unit_price
) VALUES
    (
        '66666666-6666-6666-6666-666666666667',
        '66666666-6666-6666-6666-666666666666',
        '11111111-1111-1111-1111-111111111111',
        1,
        1299.90
    )
ON CONFLICT (order_item_id) DO NOTHING;

INSERT INTO order_domain.order_packages (
    package_id, order_id, weight_kg, height_cm, width_cm, length_cm
) VALUES
    (
        'pkg_123',
        '66666666-6666-6666-6666-666666666666',
        0.450,
        8.00,
        16.00,
        22.00
    )
ON CONFLICT (package_id) DO NOTHING;

INSERT INTO order_domain.order_package_items (
    package_id, sku_id, quantity
) VALUES
    ('pkg_123', '11111111-1111-1111-1111-111111111111', 1)
ON CONFLICT (package_id, sku_id) DO NOTHING;

INSERT INTO order_domain.order_saga_states (
    order_id, current_step, status, compensation_payload, version, updated_at
) VALUES
    (
        '66666666-6666-6666-6666-666666666666',
        'completed',
        'confirmed',
        '{"inventoryReservationId":"44444444-4444-4444-4444-444444444443","capacityReservationId":"33333333-3333-3333-3333-333333333335"}',
        1,
        '2026-06-22 10:05:00-03'
    )
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO payment.payment_authorizations (
    payment_authorization_id, order_id, buyer_id, amount, currency, payment_method,
    provider, provider_authorization_id, status, authorized_at, created_at, updated_at
) VALUES
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
        '66666666-6666-6666-6666-666666666666',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        1299.90,
        'BRL',
        'credit_card',
        'mercadopago',
        'mp_auth_123',
        'captured',
        '2026-06-22 10:02:30-03',
        '2026-06-22 10:02:00-03',
        '2026-06-22 10:05:00-03'
    )
ON CONFLICT (payment_authorization_id) DO NOTHING;

INSERT INTO payment.payment_captures (
    payment_capture_id, payment_authorization_id, amount, status, provider_capture_id, captured_at
) VALUES
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
        1299.90,
        'captured',
        'mp_capture_123',
        '2026-06-22 10:05:00-03'
    )
ON CONFLICT (payment_capture_id) DO NOTHING;

INSERT INTO payment.refunds (
    refund_id, payment_capture_id, order_id, amount, reason, status
) VALUES
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
        '66666666-6666-6666-6666-666666666666',
        0.00,
        'no_refund_required_seed_placeholder',
        'not_required'
    )
ON CONFLICT (refund_id) DO NOTHING;

INSERT INTO shipment.shipments (
    shipment_id, order_id, buyer_id, seller_id, carrier_code, service_level_code,
    external_shipment_id, tracking_code, label_object_key, estimated_delivery_date,
    status, created_at, updated_at
) VALUES
    (
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        '66666666-6666-6666-6666-666666666666',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'carrier_1',
        'same_day',
        'ext_123',
        'BR123456789',
        'labels/shp_123.pdf',
        '2026-06-22',
        'in_transit',
        '2026-06-22 10:03:00-03',
        '2026-06-22 11:30:00-03'
    )
ON CONFLICT (shipment_id) DO NOTHING;

INSERT INTO shipment.shipment_volumes (
    shipment_volume_id, shipment_id, package_id, weight_kg, height_cm, width_cm, length_cm
) VALUES
    (
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeee1',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'pkg_123',
        0.450,
        8.00,
        16.00,
        22.00
    )
ON CONFLICT (shipment_volume_id) DO NOTHING;

INSERT INTO shipment.shipment_volume_items (
    shipment_volume_id, sku_id, quantity
) VALUES
    (
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeee1',
        '11111111-1111-1111-1111-111111111111',
        1
    )
ON CONFLICT (shipment_volume_id, sku_id) DO NOTHING;

INSERT INTO tracking.tracking_statuses (
    shipment_id, order_id, buyer_id, tracking_code, carrier_code, current_status,
    estimated_delivery_date, last_status_date, exception_code
) VALUES
    (
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        '66666666-6666-6666-6666-666666666666',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'BR123456789',
        'carrier_1',
        'in_transit',
        '2026-06-22',
        '2026-06-22 11:30:00-03',
        null
    )
ON CONFLICT (shipment_id) DO NOTHING;

INSERT INTO tracking.tracking_timeline (
    tracking_event_id, shipment_id, order_id, tracking_code, carrier_code,
    previous_status, current_status, status_date, exception_code, raw_payload
) VALUES
    (
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        '66666666-6666-6666-6666-666666666666',
        'BR123456789',
        'carrier_1',
        null,
        'created',
        '2026-06-22 10:03:00-03',
        null,
        '{"source":"shipment.created"}'
    ),
    (
        'dddddddd-dddd-dddd-dddd-dddddddddd02',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        '66666666-6666-6666-6666-666666666666',
        'BR123456789',
        'carrier_1',
        'created',
        'in_transit',
        '2026-06-22 11:30:00-03',
        null,
        '{"source":"carrier_webhook","hub":"HUB-SP-CENTRO"}'
    )
ON CONFLICT (tracking_event_id) DO NOTHING;

INSERT INTO notification.notification_plans (
    notification_plan_id, source_event_id, event_type, recipient_type, recipient_id,
    channel, subject, content, status, planned_at
) VALUES
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'shipment.created',
        'buyer',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'email',
        'Sua entrega foi criada',
        '{"trackingCode":"BR123456789","estimatedDeliveryDate":"2026-06-22"}',
        'sent',
        '2026-06-22 10:03:10-03'
    ),
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2',
        'dddddddd-dddd-dddd-dddd-dddddddddd02',
        'shipment.status.updated',
        'buyer',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'push',
        'Entrega em movimento',
        '{"trackingCode":"BR123456789","currentStatus":"in_transit"}',
        'sent',
        '2026-06-22 11:30:10-03'
    )
ON CONFLICT (notification_plan_id) DO NOTHING;

INSERT INTO notification.notification_logs (
    notification_id, notification_plan_id, provider, provider_message_id, status,
    attempts, sent_at, delivered_at
) VALUES
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3',
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
        'ses-demo',
        'msg_email_123',
        'delivered',
        1,
        '2026-06-22 10:03:20-03',
        '2026-06-22 10:03:22-03'
    ),
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee4',
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2',
        'fcm-demo',
        'msg_push_123',
        'delivered',
        1,
        '2026-06-22 11:30:20-03',
        '2026-06-22 11:30:21-03'
    )
ON CONFLICT (notification_id) DO NOTHING;

INSERT INTO audit.audit_entries (
    entry_id, event_id, event_type, schema_version, correlation_id, occurred_at,
    producer, topic, partition, offset_value, payload, metadata
) VALUES
    (
        'ffffffff-ffff-ffff-ffff-fffffffffff1',
        'ffffffff-ffff-ffff-ffff-fffffffff001',
        'checkout.confirmed',
        '1.0',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '2026-06-22 10:01:00-03',
        'checkout-service',
        'checkout.confirmed',
        0,
        1,
        '{"checkoutId":"55555555-5555-5555-5555-555555555555","buyerId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","sellerId":"22222222-2222-2222-2222-222222222222","shippingPromiseId":"promise_123","totalAmount":1299.90,"currency":"BRL"}',
        '{"seed":true}'
    ),
    (
        'ffffffff-ffff-ffff-ffff-fffffffffff2',
        'ffffffff-ffff-ffff-ffff-fffffffff002',
        'order.created',
        '1.0',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '2026-06-22 10:01:30-03',
        'order-service',
        'order.created',
        0,
        2,
        '{"orderId":"66666666-6666-6666-6666-666666666666","checkoutId":"55555555-5555-5555-5555-555555555555","buyerId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","sellerId":"22222222-2222-2222-2222-222222222222"}',
        '{"seed":true}'
    ),
    (
        'ffffffff-ffff-ffff-ffff-fffffffffff3',
        'ffffffff-ffff-ffff-ffff-fffffffff003',
        'shipment.status.updated',
        '1.0',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '2026-06-22 11:30:00-03',
        'tracking-service',
        'shipment.status.updated',
        0,
        3,
        '{"shipmentId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","orderId":"66666666-6666-6666-6666-666666666666","buyerId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","trackingCode":"BR123456789","carrierCode":"carrier_1","previousStatus":"created","currentStatus":"in_transit"}',
        '{"seed":true}'
    )
ON CONFLICT (event_id) DO NOTHING;

COMMIT;
