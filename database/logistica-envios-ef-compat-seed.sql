BEGIN;

UPDATE product_catalog.products
SET
    id = COALESCE(id, gen_random_uuid()),
    seller_id = COALESCE(seller_id, '22222222-2222-2222-2222-222222222222'),
    price = CASE WHEN price = 0 THEN 1299.90 ELSE price END,
    is_fragile = true,
    is_restricted = false
WHERE sku_id = '11111111-1111-1111-1111-111111111111';

INSERT INTO inventory.inventory_items (
    id, seller_id, sku_id, fulfillment_center_id, on_hand_quantity, reserved_quantity, updated_at
) VALUES
    (
        '44444444-4444-4444-4444-444444444451',
        '22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333',
        25,
        1,
        now()
    )
ON CONFLICT (id) DO NOTHING;

UPDATE fulfillment.fulfillment_centers
SET
    "Id" = '33333333-3333-3333-3333-333333333333',
    "Code" = 'FC-SP-01',
    "Name" = 'Fulfillment Center Sao Paulo 01',
    "Region" = 'Brasil Sudeste',
    "TimeZoneId" = 'America/Sao_Paulo',
    "Status" = 'Active',
    "MaximumWeightKg" = 30,
    "MaximumCubicWeightKg" = 30,
    "SupportsFragileItems" = true,
    "SupportsRestrictedItems" = true
WHERE fulfillment_center_id = '33333333-3333-3333-3333-333333333333';

INSERT INTO fulfillment.capacity_slots (
    "Id", "FulfillmentCenterId", "OperationDate", "Mode",
    "TotalCapacityUnits", "ReservedCapacityUnits", "ConsumedCapacityUnits", "UpdatedAt"
) VALUES
    (
        '33333333-3333-3333-3333-333333333341',
        '33333333-3333-3333-3333-333333333333',
        '2026-06-22',
        'Fulfillment',
        1000,
        1,
        0,
        now()
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO fulfillment.center_coverages (
    "Id", "FulfillmentCenterId", "PostalCodeFrom", "PostalCodeTo", "Mode", "Priority"
) VALUES
    (
        '33333333-3333-3333-3333-333333333342',
        '33333333-3333-3333-3333-333333333333',
        01000000,
        09999999,
        'Fulfillment',
        1
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO fulfillment.seller_center_enrollments (
    "Id", "SellerId", "FulfillmentCenterId", "Mode", "IsActive"
) VALUES
    (
        '33333333-3333-3333-3333-333333333343',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        'Fulfillment',
        true
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO fulfillment.center_operation_schedules (
    "Id", "FulfillmentCenterId", "OperationDate", "Mode",
    "IsOpen", "OpeningTime", "CutoffTime", "ClosingTime"
) VALUES
    (
        '33333333-3333-3333-3333-333333333344',
        '33333333-3333-3333-3333-333333333333',
        '2026-06-22',
        'Fulfillment',
        true,
        '08:00',
        '14:00',
        '18:00'
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO routing.logistics_nodes (
    id, code, name, region, time_zone_id, type, handling_minutes, is_active
) VALUES
    (
        '33333333-3333-3333-3333-333333333333',
        'FC-SP-01',
        'Fulfillment Center Sao Paulo 01',
        'Brasil Sudeste',
        'America/Sao_Paulo',
        'FulfillmentCenter',
        30,
        true
    ),
    (
        '77777777-7777-7777-7777-777777777771',
        'HUB-SP-CENTRO',
        'Hub Sao Paulo Centro',
        'Brasil Sudeste',
        'America/Sao_Paulo',
        'RegionalHub',
        20,
        true
    ),
    (
        '77777777-7777-7777-7777-777777777772',
        'LM-SP-ZS',
        'Last Mile Sao Paulo Zona Sul',
        'Brasil Sudeste',
        'America/Sao_Paulo',
        'LastMileStation',
        10,
        true
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO routing.logistics_lanes (
    id, origin_node_id, destination_node_id, carrier_code, mode, transit_minutes,
    maximum_weight_kg, maximum_cubic_weight_kg, supports_fragile_items,
    supports_restricted_items, status, version
) VALUES
    (
        '77777777-7777-7777-7777-777777777783',
        '33333333-3333-3333-3333-333333333333',
        '77777777-7777-7777-7777-777777777771',
        'carrier_1',
        'Road',
        60,
        30,
        30,
        true,
        true,
        'Active',
        1
    ),
    (
        '77777777-7777-7777-7777-777777777784',
        '77777777-7777-7777-7777-777777777771',
        '77777777-7777-7777-7777-777777777772',
        'carrier_1',
        'LastMile',
        90,
        30,
        30,
        true,
        true,
        'Active',
        1
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO routing.lane_schedules (
    id, logistics_lane_id, day_of_week, departure_time, is_active
) VALUES
    ('77777777-7777-7777-7777-777777777785', '77777777-7777-7777-7777-777777777783', 'Monday', '09:00', true),
    ('77777777-7777-7777-7777-777777777786', '77777777-7777-7777-7777-777777777784', 'Monday', '11:00', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO routing.postal_coverages (
    id, destination_node_id, postal_code_from, postal_code_to, priority
) VALUES
    (
        '77777777-7777-7777-7777-777777777787',
        '77777777-7777-7777-7777-777777777772',
        01000000,
        09999999,
        1
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO routing.network_versions (region, version, updated_at)
VALUES ('Brasil Sudeste', 1, now())
ON CONFLICT (region) DO UPDATE SET version = EXCLUDED.version, updated_at = EXCLUDED.updated_at;

UPDATE carrier.carriers
SET
    "Id" = '88888888-8888-8888-8888-888888888800',
    "Code" = 'carrier_1',
    "Name" = 'Carrier Demo Express',
    "Status" = 'Active',
    "RequiresRealTimeValidation" = false
WHERE carrier_code = 'carrier_1';

INSERT INTO carrier.carrier_service_levels (
    "Id", "CarrierId", "Code", "Name", "Mode", "MaximumWeightKg",
    "MaximumCubicWeightKg", "SupportsFragileItems", "SupportsRestrictedItems",
    "Priority", "IsActive"
) VALUES
    (
        '88888888-8888-8888-8888-888888888801',
        '88888888-8888-8888-8888-888888888800',
        'same_day',
        'Entrega no mesmo dia',
        'FULFILLMENT',
        30,
        30,
        true,
        true,
        1,
        true
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO carrier.carrier_lanes (
    "Id", "CarrierServiceLevelId", "OriginNodeId", "DestinationNodeId", "TimeZoneId",
    "CutoffTime", "OperatesOnMonday", "OperatesOnTuesday", "OperatesOnWednesday",
    "OperatesOnThursday", "OperatesOnFriday", "OperatesOnSaturday", "OperatesOnSunday", "IsActive"
) VALUES
    (
        '88888888-8888-8888-8888-888888888802',
        '88888888-8888-8888-8888-888888888801',
        '33333333-3333-3333-3333-333333333333',
        '77777777-7777-7777-7777-777777777772',
        'America/Sao_Paulo',
        '14:00',
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        true
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO pricing.postal_zones (
    "Id", "Code", "PostalCodeFrom", "PostalCodeTo", "IsRemoteArea", "Priority"
) VALUES
    (
        '99999999-9999-9999-9999-999999999981',
        'SP-CAPITAL',
        01000000,
        09999999,
        false,
        1
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO pricing.rate_cards (
    "Id", "Code", "CarrierCode", "ServiceLevelCode", "Currency",
    "Version", "Status", "EffectiveFrom", "EffectiveUntil"
) VALUES
    (
        '99999999-9999-9999-9999-999999999982',
        'CARRIER1-SAMEDAY-BRL',
        'carrier_1',
        'same_day',
        'BRL',
        1,
        'Active',
        '2026-01-01 00:00:00-03',
        '2026-12-31 23:59:59-03'
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO pricing.rate_bands (
    "Id", "RateCardId", "OriginNodeId", "DestinationZone",
    "MinimumWeightKg", "MaximumWeightKg", "BasePrice", "IncludedWeightKg",
    "WeightIncrementKg", "PricePerWeightIncrement", "FuelSurchargePercentage",
    "RemoteAreaFee", "FragileFee", "OversizeThresholdKg", "OversizeFee", "MinimumLogisticsCost"
) VALUES
    (
        '99999999-9999-9999-9999-999999999983',
        '99999999-9999-9999-9999-999999999982',
        '33333333-3333-3333-3333-333333333333',
        'SP-CAPITAL',
        0,
        2,
        14.90,
        1,
        1,
        3.00,
        0,
        0,
        0,
        30,
        0,
        10.00
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO pricing.promotion_rules (
    "Id", "Code", "SellerId", "Priority", "MinimumCartTotal",
    "CustomerDiscountPercentage", "PlatformSubsidyPercentage", "SellerSubsidyPercentage",
    "MaximumBenefit", "StartsAt", "EndsAt", "IsActive"
) VALUES
    (
        '99999999-9999-9999-9999-999999999984',
        'FREE_SAME_DAY_DEMO',
        '22222222-2222-2222-2222-222222222222',
        1,
        100,
        0,
        10,
        0,
        20,
        '2026-01-01 00:00:00-03',
        '2026-12-31 23:59:59-03',
        true
    )
ON CONFLICT ("Id") DO NOTHING;

INSERT INTO tracking.tracking_events (
    id, shipment_id, order_id, buyer_id, provider_event_id, tracking_code, carrier_code,
    carrier_sequence, status, description, occurred_at, received_at, estimated_delivery_date,
    facility_code, location_city, location_state, location_country
) VALUES
    (
        'dddddddd-dddd-dddd-dddd-dddddddddd11',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        '66666666-6666-6666-6666-666666666666',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'carrier_evt_001',
        'BR123456789',
        'carrier_1',
        1,
        'InTransit',
        'Pacote em transito',
        '2026-06-22 11:30:00-03',
        '2026-06-22 11:30:05-03',
        '2026-06-22',
        'HUB-SP-CENTRO',
        'Sao Paulo',
        'SP',
        'BR'
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO tracking.shipment_tracking (
    shipment_id, order_id, buyer_id, tracking_code, carrier_code, current_status,
    last_event_id, last_carrier_sequence, last_event_occurred_at, last_event_received_at,
    estimated_delivery_date, version, last_facility_code, last_location_city,
    last_location_state, last_location_country
) VALUES
    (
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        '66666666-6666-6666-6666-666666666666',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'BR123456789',
        'carrier_1',
        'InTransit',
        'dddddddd-dddd-dddd-dddd-dddddddddd11',
        1,
        '2026-06-22 11:30:00-03',
        '2026-06-22 11:30:05-03',
        '2026-06-22',
        1,
        'HUB-SP-CENTRO',
        'Sao Paulo',
        'SP',
        'BR'
    )
ON CONFLICT (shipment_id) DO NOTHING;

COMMIT;
