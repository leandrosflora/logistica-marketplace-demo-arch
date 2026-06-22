CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Compatibility layer for the actual EF Core DbContexts in the local microservice repos.
-- It keeps the canonical architecture schema intact and adds the tables/columns that
-- the current service implementations expect through EF mappings and conventions.

-- CheckoutService
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "Id" uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "BuyerId" uuid;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "SellerId" uuid;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "Status" text;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "ItemsTotal" numeric(18,2) DEFAULT 0;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "ShippingCost" numeric(18,2) DEFAULT 0;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "TotalAmount" numeric(18,2) DEFAULT 0;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "ShippingPromiseId" text DEFAULT '';
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "ShippingMode" text DEFAULT '';
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "Carrier" text DEFAULT '';
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "EstimatedDeliveryDate" date;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "IdempotencyKey" text DEFAULT gen_random_uuid()::text;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "ConfirmationIdempotencyKey" text;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "PaymentIntentId" text;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz DEFAULT now();
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "ExpiresAt" timestamptz DEFAULT now();
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS "ConfirmedAt" timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_checkouts_ef_id ON checkout.checkouts ("Id");
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_checkouts_idempotency_key ON checkout.checkouts ("IdempotencyKey");

ALTER TABLE checkout.checkout_items ADD COLUMN IF NOT EXISTS "Id" uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.checkout_items ADD COLUMN IF NOT EXISTS "CheckoutId" uuid;
ALTER TABLE checkout.checkout_items ADD COLUMN IF NOT EXISTS "SkuId" uuid;
ALTER TABLE checkout.checkout_items ADD COLUMN IF NOT EXISTS "Quantity" integer;
ALTER TABLE checkout.checkout_items ADD COLUMN IF NOT EXISTS "UnitPrice" numeric(18,2);
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_items_ef_id ON checkout.checkout_items ("Id");

ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "Id" uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "EventId" uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "CorrelationId" text DEFAULT '';
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "CheckoutId" uuid;
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "PromiseId" text DEFAULT '';
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "Mode" text DEFAULT '';
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "Carrier" text DEFAULT '';
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "EstimatedDeliveryDate" date;
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "Cost" numeric(18,2) DEFAULT 0;
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS "ProcessedAt" timestamptz DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_shipping_promise_projections_ef_id ON checkout.shipping_promise_projections ("Id");

ALTER TABLE checkout.outbox_messages ADD COLUMN IF NOT EXISTS "Id" uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.outbox_messages ADD COLUMN IF NOT EXISTS "EventType" text;
ALTER TABLE checkout.outbox_messages ADD COLUMN IF NOT EXISTS "Payload" jsonb;
ALTER TABLE checkout.outbox_messages ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz DEFAULT now();
ALTER TABLE checkout.outbox_messages ADD COLUMN IF NOT EXISTS "ProcessedAt" timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_outbox_messages_ef_id ON checkout.outbox_messages ("Id");

-- ProductCatalogService
ALTER TABLE product_catalog.products ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE product_catalog.products ADD COLUMN IF NOT EXISTS seller_id uuid;
ALTER TABLE product_catalog.products ADD COLUMN IF NOT EXISTS price numeric(18,2) DEFAULT 0;
ALTER TABLE product_catalog.products ADD COLUMN IF NOT EXISTS is_fragile boolean DEFAULT false;
ALTER TABLE product_catalog.products ADD COLUMN IF NOT EXISTS is_restricted boolean DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS ux_product_catalog_products_id ON product_catalog.products (id);

CREATE TABLE IF NOT EXISTS product_catalog.outbox_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz
);

-- InventoryService
CREATE TABLE IF NOT EXISTS inventory.inventory_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    sku_id uuid NOT NULL,
    fulfillment_center_id uuid NOT NULL,
    on_hand_quantity integer NOT NULL DEFAULT 0,
    reserved_quantity integer NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_inventory_non_negative CHECK (
        on_hand_quantity >= 0 AND reserved_quantity >= 0 AND reserved_quantity <= on_hand_quantity
    )
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_items_lookup ON inventory.inventory_items (seller_id, sku_id, fulfillment_center_id);

ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS checkout_id uuid;
ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS seller_id uuid;
ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS idempotency_key text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_reservations_id ON inventory.inventory_reservations (id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_reservations_idempotency_key ON inventory.inventory_reservations (idempotency_key) WHERE idempotency_key IS NOT NULL;

ALTER TABLE inventory.inventory_reservation_items ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE inventory.inventory_reservation_items ADD COLUMN IF NOT EXISTS reservation_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_reservation_items_id ON inventory.inventory_reservation_items (id);

CREATE TABLE IF NOT EXISTS inventory.outbox_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type text,
    payload jsonb,
    created_at timestamptz DEFAULT now(),
    processed_at timestamptz
);
ALTER TABLE inventory.outbox_messages ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE inventory.outbox_messages ADD COLUMN IF NOT EXISTS event_type text;
ALTER TABLE inventory.outbox_messages ADD COLUMN IF NOT EXISTS payload jsonb;
ALTER TABLE inventory.outbox_messages ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE inventory.outbox_messages ADD COLUMN IF NOT EXISTS processed_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_outbox_messages_id ON inventory.outbox_messages (id);

-- FulfillmentCenterService
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "Id" uuid DEFAULT gen_random_uuid();
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "Code" text;
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "Name" text;
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "Region" text DEFAULT 'Brasil Sudeste';
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "TimeZoneId" text DEFAULT 'America/Sao_Paulo';
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "Status" text DEFAULT 'Active';
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "MaximumWeightKg" numeric(10,3) DEFAULT 30;
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "MaximumCubicWeightKg" numeric(10,3) DEFAULT 30;
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "SupportsFragileItems" boolean DEFAULT true;
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "SupportsRestrictedItems" boolean DEFAULT true;
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz DEFAULT now();
ALTER TABLE fulfillment.fulfillment_centers ADD COLUMN IF NOT EXISTS "UpdatedAt" timestamptz DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS ux_fulfillment_centers_ef_id ON fulfillment.fulfillment_centers ("Id");

CREATE TABLE IF NOT EXISTS fulfillment.capacity_slots (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "FulfillmentCenterId" uuid NOT NULL,
    "OperationDate" date NOT NULL,
    "Mode" text NOT NULL,
    "TotalCapacityUnits" integer NOT NULL DEFAULT 0,
    "ReservedCapacityUnits" integer NOT NULL DEFAULT 0,
    "ConsumedCapacityUnits" integer NOT NULL DEFAULT 0,
    "UpdatedAt" timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_capacity_slots_allocated_capacity CHECK (
        "TotalCapacityUnits" >= 0 AND "ReservedCapacityUnits" >= 0 AND "ConsumedCapacityUnits" >= 0
        AND "ReservedCapacityUnits" + "ConsumedCapacityUnits" <= "TotalCapacityUnits"
    )
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_capacity_slots_fc_date_mode ON fulfillment.capacity_slots ("FulfillmentCenterId", "OperationDate", "Mode");

ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "Id" uuid DEFAULT gen_random_uuid();
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "OrderId" uuid;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "FulfillmentCenterId" uuid;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "OperationDate" date;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "Mode" text;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "ReservedCapacityUnits" integer DEFAULT 1;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "IdempotencyKey" text;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "Status" text;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz DEFAULT now();
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "ExpiresAt" timestamptz DEFAULT now();
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "ConfirmedAt" timestamptz;
ALTER TABLE fulfillment.capacity_reservations ADD COLUMN IF NOT EXISTS "ReleasedAt" timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_capacity_reservations_ef_id ON fulfillment.capacity_reservations ("Id");

CREATE TABLE IF NOT EXISTS fulfillment.center_coverages (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "FulfillmentCenterId" uuid NOT NULL,
    "PostalCodeFrom" bigint NOT NULL,
    "PostalCodeTo" bigint NOT NULL,
    "Mode" text NOT NULL,
    "Priority" integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS fulfillment.seller_center_enrollments (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "SellerId" uuid NOT NULL,
    "FulfillmentCenterId" uuid NOT NULL,
    "Mode" text NOT NULL,
    "IsActive" boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS fulfillment.center_operation_schedules (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "FulfillmentCenterId" uuid NOT NULL,
    "OperationDate" date NOT NULL,
    "Mode" text NOT NULL,
    "IsOpen" boolean NOT NULL DEFAULT true,
    "OpeningTime" time NOT NULL DEFAULT '08:00',
    "CutoffTime" time NOT NULL DEFAULT '14:00',
    "ClosingTime" time NOT NULL DEFAULT '18:00'
);
CREATE TABLE IF NOT EXISTS fulfillment.outbox_messages (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "EventType" text NOT NULL,
    "PayloadJson" text NOT NULL,
    "OccurredAt" timestamptz NOT NULL DEFAULT now(),
    "ProcessedAt" timestamptz
);

-- RoutingService
CREATE TABLE IF NOT EXISTS routing.logistics_nodes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL,
    name text NOT NULL,
    region text NOT NULL,
    time_zone_id text NOT NULL DEFAULT 'America/Sao_Paulo',
    type text NOT NULL,
    handling_minutes integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_routing_logistics_nodes_code ON routing.logistics_nodes (code);

CREATE TABLE IF NOT EXISTS routing.logistics_lanes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    origin_node_id uuid NOT NULL,
    destination_node_id uuid NOT NULL,
    carrier_code text NOT NULL,
    mode text NOT NULL,
    transit_minutes integer NOT NULL,
    maximum_weight_kg numeric(10,3) NOT NULL DEFAULT 30,
    maximum_cubic_weight_kg numeric(10,3) NOT NULL DEFAULT 30,
    supports_fragile_items boolean NOT NULL DEFAULT true,
    supports_restricted_items boolean NOT NULL DEFAULT true,
    status text NOT NULL DEFAULT 'Active',
    version bigint NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS routing.lane_schedules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    logistics_lane_id uuid NOT NULL,
    day_of_week text NOT NULL,
    departure_time time NOT NULL,
    is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS routing.postal_coverages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    destination_node_id uuid NOT NULL,
    postal_code_from bigint NOT NULL,
    postal_code_to bigint NOT NULL,
    priority integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS routing.network_versions (
    region text PRIMARY KEY,
    version bigint NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS routing.outbox_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    type text NOT NULL,
    payload jsonb NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz
);

-- CarrierService
ALTER TABLE carrier.carriers ALTER COLUMN carrier_code SET DEFAULT gen_random_uuid()::text;
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "Id" uuid DEFAULT gen_random_uuid();
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "Code" text;
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "Name" text;
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "Status" text DEFAULT 'Active';
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "RequiresRealTimeValidation" boolean DEFAULT false;
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "StatusUpdatedAt" timestamptz DEFAULT now();
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "CreatedAt" timestamptz DEFAULT now();
ALTER TABLE carrier.carriers ADD COLUMN IF NOT EXISTS "UpdatedAt" timestamptz DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS ux_carriers_ef_id ON carrier.carriers ("Id");

CREATE TABLE IF NOT EXISTS carrier.carrier_service_levels (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "CarrierId" uuid NOT NULL,
    "Code" text NOT NULL,
    "Name" text NOT NULL,
    "Mode" text NOT NULL,
    "MaximumWeightKg" numeric(12,3) NOT NULL DEFAULT 30,
    "MaximumCubicWeightKg" numeric(12,3) NOT NULL DEFAULT 30,
    "SupportsFragileItems" boolean NOT NULL DEFAULT true,
    "SupportsRestrictedItems" boolean NOT NULL DEFAULT true,
    "Priority" integer NOT NULL DEFAULT 0,
    "IsActive" boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS carrier.carrier_lanes (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "CarrierServiceLevelId" uuid NOT NULL,
    "OriginNodeId" uuid NOT NULL,
    "DestinationNodeId" uuid NOT NULL,
    "TimeZoneId" text NOT NULL DEFAULT 'America/Sao_Paulo',
    "CutoffTime" time NOT NULL DEFAULT '14:00',
    "OperatesOnMonday" boolean NOT NULL DEFAULT true,
    "OperatesOnTuesday" boolean NOT NULL DEFAULT true,
    "OperatesOnWednesday" boolean NOT NULL DEFAULT true,
    "OperatesOnThursday" boolean NOT NULL DEFAULT true,
    "OperatesOnFriday" boolean NOT NULL DEFAULT true,
    "OperatesOnSaturday" boolean NOT NULL DEFAULT false,
    "OperatesOnSunday" boolean NOT NULL DEFAULT false,
    "IsActive" boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS carrier.carrier_category_restrictions (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "CarrierServiceLevelId" uuid NOT NULL,
    "Category" text NOT NULL,
    "IsBlocked" boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS carrier.carrier_incidents (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "CarrierId" uuid NOT NULL,
    "IncidentType" text NOT NULL,
    "Reason" text NOT NULL,
    "StartedAt" timestamptz NOT NULL DEFAULT now(),
    "ResolvedAt" timestamptz
);
CREATE TABLE IF NOT EXISTS carrier.outbox_messages (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "EventType" text NOT NULL,
    "Payload" jsonb NOT NULL,
    "CreatedAt" timestamptz NOT NULL DEFAULT now(),
    "ProcessedAt" timestamptz
);

-- ShippingPricingService
CREATE TABLE IF NOT EXISTS pricing.rate_cards (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "Code" text NOT NULL,
    "CarrierCode" text NOT NULL,
    "ServiceLevelCode" text NOT NULL,
    "Currency" text NOT NULL DEFAULT 'BRL',
    "Version" bigint NOT NULL DEFAULT 1,
    "Status" text NOT NULL DEFAULT 'Active',
    "EffectiveFrom" timestamptz NOT NULL DEFAULT now(),
    "EffectiveUntil" timestamptz NOT NULL DEFAULT '2999-12-31'
);
CREATE TABLE IF NOT EXISTS pricing.rate_bands (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "RateCardId" uuid NOT NULL,
    "OriginNodeId" uuid NOT NULL,
    "DestinationZone" text NOT NULL,
    "MinimumWeightKg" numeric(12,3) NOT NULL DEFAULT 0,
    "MaximumWeightKg" numeric(12,3) NOT NULL DEFAULT 30,
    "BasePrice" numeric(18,4) NOT NULL DEFAULT 0,
    "IncludedWeightKg" numeric(12,3) NOT NULL DEFAULT 0,
    "WeightIncrementKg" numeric(12,3) NOT NULL DEFAULT 1,
    "PricePerWeightIncrement" numeric(18,4) NOT NULL DEFAULT 0,
    "FuelSurchargePercentage" numeric(8,4) NOT NULL DEFAULT 0,
    "RemoteAreaFee" numeric(18,4) NOT NULL DEFAULT 0,
    "FragileFee" numeric(18,4) NOT NULL DEFAULT 0,
    "OversizeThresholdKg" numeric(12,3) NOT NULL DEFAULT 30,
    "OversizeFee" numeric(18,4) NOT NULL DEFAULT 0,
    "MinimumLogisticsCost" numeric(18,4) NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS pricing.postal_zones (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "Code" text NOT NULL,
    "PostalCodeFrom" bigint NOT NULL,
    "PostalCodeTo" bigint NOT NULL,
    "IsRemoteArea" boolean NOT NULL DEFAULT false,
    "Priority" integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS pricing.promotion_rules (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "Code" text NOT NULL,
    "SellerId" uuid,
    "Priority" integer NOT NULL DEFAULT 0,
    "MinimumCartTotal" numeric(18,2) NOT NULL DEFAULT 0,
    "CustomerDiscountPercentage" numeric(8,4) NOT NULL DEFAULT 0,
    "PlatformSubsidyPercentage" numeric(8,4) NOT NULL DEFAULT 0,
    "SellerSubsidyPercentage" numeric(8,4) NOT NULL DEFAULT 0,
    "MaximumBenefit" numeric(18,2) NOT NULL DEFAULT 0,
    "StartsAt" timestamptz NOT NULL DEFAULT now(),
    "EndsAt" timestamptz NOT NULL DEFAULT '2999-12-31',
    "IsActive" boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS pricing.outbox_messages (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "EventType" text NOT NULL,
    "Payload" jsonb NOT NULL,
    "OccurredAt" timestamptz NOT NULL DEFAULT now(),
    "ProcessedAt" timestamptz
);

-- ShippingPromiseService
CREATE TABLE IF NOT EXISTS shipping_promise.shipping_promise_audits (
    "Id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "RequestJson" jsonb NOT NULL,
    "ResponseJson" jsonb NOT NULL,
    "CandidatesJson" jsonb NOT NULL,
    "CreatedAt" timestamptz NOT NULL DEFAULT now()
);

-- OrderService
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS items_total numeric(18,2) DEFAULT 0;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS shipping_price numeric(18,2) DEFAULT 0;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS pricing_quote_id uuid;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS inventory_reservation_id uuid;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS capacity_reservation_id uuid;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS payment_authorization_id uuid;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS shipment_id uuid;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS shipment_status text;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS shipment_status_updated_at timestamptz;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS inventory_state text;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS capacity_state text;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS payment_state text;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS shipment_state text;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS version bigint DEFAULT 1;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_orders_id ON order_domain.orders (id);

ALTER TABLE order_domain.order_items ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE order_domain.order_items ADD COLUMN IF NOT EXISTS title text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_order_items_id ON order_domain.order_items (id);

ALTER TABLE order_domain.inbox_messages ALTER COLUMN event_id SET DEFAULT gen_random_uuid();
ALTER TABLE order_domain.inbox_messages ADD COLUMN IF NOT EXISTS message_id uuid DEFAULT gen_random_uuid();
ALTER TABLE order_domain.inbox_messages ADD COLUMN IF NOT EXISTS message_type text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_inbox_messages_message_id ON order_domain.inbox_messages (message_id);

ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS message_type text;
ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS aggregate_key text;
ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_outbox_messages_id ON order_domain.outbox_messages (id);

-- ShipmentService
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS shipment_request_id uuid;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS shipping_promise_id text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS route_id text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS origin_node_id uuid;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS promised_delivery_date date;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS label_sha256 text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS booking_attempts integer DEFAULT 0;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS last_error text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS processing_token uuid;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS processing_lease_until timestamptz;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS version bigint DEFAULT 1;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS ready_at timestamptz;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS recipient_name text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS street text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS number text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS complement text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS district text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS state text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS destination_postal_code text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS country text;
ALTER TABLE shipment.shipments ADD COLUMN IF NOT EXISTS phone text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_shipment_shipments_id ON shipment.shipments (id);

CREATE TABLE IF NOT EXISTS shipment.shipment_packages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id uuid,
    sequence integer NOT NULL,
    weight_kg numeric(12,3) NOT NULL DEFAULT 0,
    height_cm numeric(12,2) NOT NULL DEFAULT 0,
    width_cm numeric(12,2) NOT NULL DEFAULT 0,
    length_cm numeric(12,2) NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS shipment.shipment_package_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_package_id uuid,
    sku_id uuid NOT NULL,
    quantity integer NOT NULL
);

ALTER TABLE shipment.inbox_messages ALTER COLUMN event_id SET DEFAULT gen_random_uuid();
ALTER TABLE shipment.inbox_messages ADD COLUMN IF NOT EXISTS message_id uuid DEFAULT gen_random_uuid();
ALTER TABLE shipment.inbox_messages ADD COLUMN IF NOT EXISTS message_type text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_shipment_inbox_messages_message_id ON shipment.inbox_messages (message_id);
ALTER TABLE shipment.outbox_messages ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE shipment.outbox_messages ADD COLUMN IF NOT EXISTS message_type text;
ALTER TABLE shipment.outbox_messages ADD COLUMN IF NOT EXISTS aggregate_key text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_shipment_outbox_messages_id ON shipment.outbox_messages (id);

-- TrackingService
CREATE TABLE IF NOT EXISTS tracking.tracking_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id uuid NOT NULL,
    order_id uuid NOT NULL,
    buyer_id uuid NOT NULL,
    provider_event_id text NOT NULL,
    tracking_code text NOT NULL,
    carrier_code text NOT NULL,
    carrier_sequence bigint,
    status text NOT NULL,
    description text,
    exception_code text,
    occurred_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    estimated_delivery_date date,
    facility_code text,
    location_city text,
    location_state text,
    location_country text
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tracking_events_provider ON tracking.tracking_events (carrier_code, provider_event_id);

CREATE TABLE IF NOT EXISTS tracking.shipment_tracking (
    shipment_id uuid PRIMARY KEY,
    order_id uuid NOT NULL,
    buyer_id uuid NOT NULL,
    tracking_code text NOT NULL,
    carrier_code text NOT NULL,
    current_status text NOT NULL,
    last_event_id uuid,
    last_carrier_sequence bigint,
    last_event_occurred_at timestamptz,
    last_event_received_at timestamptz,
    estimated_delivery_date date,
    delivered_at timestamptz,
    current_exception_code text,
    version bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    last_facility_code text,
    last_location_city text,
    last_location_state text,
    last_location_country text
);

ALTER TABLE tracking.inbox_messages ALTER COLUMN event_id SET DEFAULT gen_random_uuid();
ALTER TABLE tracking.inbox_messages ADD COLUMN IF NOT EXISTS message_id uuid DEFAULT gen_random_uuid();
ALTER TABLE tracking.inbox_messages ADD COLUMN IF NOT EXISTS message_type text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_tracking_inbox_messages_message_id ON tracking.inbox_messages (message_id);
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS message_type text;
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS aggregate_key text;
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_tracking_outbox_messages_id ON tracking.outbox_messages (id);

-- NotificationService
CREATE TABLE IF NOT EXISTS notification.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_event_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    type text NOT NULL,
    priority text NOT NULL,
    status text NOT NULL,
    locale text NOT NULL DEFAULT 'pt-BR',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_notifications_source_event_id ON notification.notifications (source_event_id);

CREATE TABLE IF NOT EXISTS notification.notification_deliveries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id uuid NOT NULL,
    channel text NOT NULL,
    status text NOT NULL,
    destination text NOT NULL,
    template_id uuid NOT NULL,
    template_version integer NOT NULL DEFAULT 1,
    subject text,
    body text NOT NULL,
    provider_message_id text,
    attempts integer NOT NULL DEFAULT 0,
    not_before timestamptz NOT NULL DEFAULT now(),
    next_attempt_at timestamptz,
    processing_token uuid,
    processing_lease_until timestamptz,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    accepted_at timestamptz,
    delivered_at timestamptz
);
CREATE TABLE IF NOT EXISTS notification.notification_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    type text NOT NULL,
    channel text NOT NULL,
    locale text NOT NULL,
    version integer NOT NULL,
    subject_template text,
    body_template text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS notification.notification_preferences (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id uuid NOT NULL,
    notification_type text NOT NULL,
    channel text NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS notification.recipient_contacts (
    recipient_id uuid PRIMARY KEY,
    locale text NOT NULL DEFAULT 'pt-BR',
    email text,
    phone_number text,
    push_token text,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE notification.inbox_messages ALTER COLUMN event_id SET DEFAULT gen_random_uuid();
ALTER TABLE notification.inbox_messages ADD COLUMN IF NOT EXISTS message_id uuid DEFAULT gen_random_uuid();
ALTER TABLE notification.inbox_messages ADD COLUMN IF NOT EXISTS message_type text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_notification_inbox_messages_message_id ON notification.inbox_messages (message_id);
CREATE TABLE IF NOT EXISTS notification.outbox_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    topic text,
    message_type text,
    aggregate_key text,
    payload jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    attempts integer NOT NULL DEFAULT 0,
    next_attempt_at timestamptz,
    last_error text
);
