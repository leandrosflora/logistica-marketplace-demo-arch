-- Logistica Envios database initialization script
-- Use this file to recreate the local PostgreSQL database from an empty volume.
-- Execution order: canonical schema, canonical seed data, EF Core compatibility schema, EF Core compatibility seed data.


-- ============================================================================
-- Canonical schema (from logistica-envios-schema.sql)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS checkout;
CREATE SCHEMA IF NOT EXISTS shipping_promise;
CREATE SCHEMA IF NOT EXISTS product_catalog;
CREATE SCHEMA IF NOT EXISTS product_search;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS fulfillment;
CREATE SCHEMA IF NOT EXISTS routing;
CREATE SCHEMA IF NOT EXISTS carrier;
CREATE SCHEMA IF NOT EXISTS pricing;
CREATE SCHEMA IF NOT EXISTS order_domain;
CREATE SCHEMA IF NOT EXISTS payment;
CREATE SCHEMA IF NOT EXISTS shipment;
CREATE SCHEMA IF NOT EXISTS tracking;
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS order_visibility;
CREATE SCHEMA IF NOT EXISTS admin_bff;

CREATE TABLE IF NOT EXISTS checkout.checkouts (
    checkout_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    status text NOT NULL,
    shipping_promise_id text,
    total_amount numeric(12,2) NOT NULL DEFAULT 0,
    currency char(3) NOT NULL DEFAULT 'BRL',
    destination jsonb NOT NULL DEFAULT '{}'::jsonb,
    correlation_id uuid,
    expires_at timestamptz,
    confirmed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS checkout.checkout_items (
    checkout_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_id uuid NOT NULL REFERENCES checkout.checkouts(checkout_id) ON DELETE CASCADE,
    sku_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS checkout.shipping_promise_projections (
    promise_id text PRIMARY KEY,
    checkout_id uuid NOT NULL REFERENCES checkout.checkouts(checkout_id) ON DELETE CASCADE,
    buyer_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    mode text NOT NULL,
    carrier_code text NOT NULL,
    estimated_delivery_date date NOT NULL,
    cost numeric(12,2) NOT NULL CHECK (cost >= 0),
    currency char(3) NOT NULL DEFAULT 'BRL',
    source text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    received_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shipping_promise.shipping_promises (
    promise_id text PRIMARY KEY,
    checkout_id uuid,
    buyer_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    mode text NOT NULL,
    carrier_code text NOT NULL,
    route_id text,
    service_level_code text,
    origin_node_id uuid,
    estimated_delivery_date date NOT NULL,
    cost numeric(12,2) NOT NULL CHECK (cost >= 0),
    currency char(3) NOT NULL DEFAULT 'BRL',
    source text NOT NULL,
    status text NOT NULL DEFAULT 'calculated',
    request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    result_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    correlation_id uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS product_catalog.products (
    sku_id uuid PRIMARY KEY,
    title text NOT NULL,
    category text NOT NULL,
    weight_kg numeric(10,3) NOT NULL CHECK (weight_kg >= 0),
    height_cm numeric(10,2) NOT NULL CHECK (height_cm >= 0),
    width_cm numeric(10,2) NOT NULL CHECK (width_cm >= 0),
    length_cm numeric(10,2) NOT NULL CHECK (length_cm >= 0),
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS product_catalog.product_restrictions (
    sku_id uuid NOT NULL REFERENCES product_catalog.products(sku_id) ON DELETE CASCADE,
    restriction_code text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (sku_id, restriction_code)
);

CREATE TABLE IF NOT EXISTS product_search.product_index (
    sku_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    title text NOT NULL,
    category text,
    price numeric(12,2) NOT NULL CHECK (price >= 0),
    thumbnail_url text,
    available_quantity integer NOT NULL DEFAULT 0 CHECK (available_quantity >= 0),
    searchable_text text NOT NULL,
    indexed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (sku_id, seller_id)
);

CREATE TABLE IF NOT EXISTS inventory.inventory_balances (
    inventory_balance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sku_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    fulfillment_center_id uuid NOT NULL,
    total_quantity integer NOT NULL DEFAULT 0 CHECK (total_quantity >= 0),
    reserved_quantity integer NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
    available_quantity integer GENERATED ALWAYS AS (total_quantity - reserved_quantity) STORED,
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (sku_id, seller_id, fulfillment_center_id),
    CHECK (reserved_quantity <= total_quantity)
);

CREATE TABLE IF NOT EXISTS inventory.inventory_reservations (
    reservation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid,
    checkout_id uuid,
    status text NOT NULL DEFAULT 'pending',
    -- InventoryService's own schema.sql (and InventoryDbContext) treat idempotency
    -- keys as opaque strings (e.g. "reserve:<orderId>"), not UUIDs; keep this in
    -- sync with varchar(200), matching InventoryDbContext's IdempotencyKey mapping.
    idempotency_key varchar(200),
    expires_at timestamptz,
    confirmed_at timestamptz,
    released_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inventory.inventory_reservation_items (
    reservation_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id uuid NOT NULL REFERENCES inventory.inventory_reservations(reservation_id) ON DELETE CASCADE,
    sku_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    fulfillment_center_id uuid NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0)
);

CREATE TABLE IF NOT EXISTS inventory.inventory_adjustments (
    adjustment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sku_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    fulfillment_center_id uuid NOT NULL,
    quantity_delta integer NOT NULL,
    reason text NOT NULL,
    created_by text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fulfillment.fulfillment_centers (
    fulfillment_center_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    zip_code text NOT NULL,
    city text NOT NULL,
    state char(2) NOT NULL,
    country char(2) NOT NULL DEFAULT 'BR',
    daily_cutoff time NOT NULL,
    timezone text NOT NULL DEFAULT 'America/Sao_Paulo',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fulfillment.capacity_windows (
    capacity_window_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fulfillment_center_id uuid NOT NULL REFERENCES fulfillment.fulfillment_centers(fulfillment_center_id) ON DELETE CASCADE,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    total_capacity integer NOT NULL CHECK (total_capacity >= 0),
    reserved_capacity integer NOT NULL DEFAULT 0 CHECK (reserved_capacity >= 0),
    confirmed_capacity integer NOT NULL DEFAULT 0 CHECK (confirmed_capacity >= 0),
    CHECK (starts_at < ends_at)
);

CREATE TABLE IF NOT EXISTS fulfillment.capacity_reservations (
    reservation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    capacity_window_id uuid NOT NULL REFERENCES fulfillment.capacity_windows(capacity_window_id),
    order_id uuid,
    quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
    status text NOT NULL DEFAULT 'pending',
    idempotency_key uuid,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS routing.network_nodes (
    node_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    node_type text NOT NULL,
    name text NOT NULL,
    zip_code text,
    city text,
    state char(2),
    country char(2) NOT NULL DEFAULT 'BR',
    status text NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS routing.network_lanes (
    lane_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    origin_node_id uuid NOT NULL REFERENCES routing.network_nodes(node_id),
    destination_node_id uuid NOT NULL REFERENCES routing.network_nodes(node_id),
    corridor text NOT NULL,
    distance_km numeric(10,2),
    status text NOT NULL DEFAULT 'active',
    UNIQUE (origin_node_id, destination_node_id)
);

CREATE TABLE IF NOT EXISTS routing.routes (
    route_id text PRIMARY KEY,
    origin_node_id uuid NOT NULL,
    destination_zip_code text NOT NULL,
    mode text NOT NULL,
    service_level_code text NOT NULL,
    sla_days integer NOT NULL CHECK (sla_days >= 0),
    corridor text NOT NULL,
    valid_from timestamptz NOT NULL DEFAULT now(),
    valid_to timestamptz
);

CREATE TABLE IF NOT EXISTS routing.route_hubs (
    route_id text NOT NULL REFERENCES routing.routes(route_id) ON DELETE CASCADE,
    sequence_number integer NOT NULL CHECK (sequence_number > 0),
    node_id uuid NOT NULL REFERENCES routing.network_nodes(node_id),
    PRIMARY KEY (route_id, sequence_number)
);

CREATE TABLE IF NOT EXISTS carrier.carriers (
    carrier_code text PRIMARY KEY,
    name text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    integration_type text NOT NULL DEFAULT 'api',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS carrier.service_levels (
    carrier_code text NOT NULL REFERENCES carrier.carriers(carrier_code) ON DELETE CASCADE,
    service_level_code text NOT NULL,
    name text NOT NULL,
    min_sla_days integer NOT NULL CHECK (min_sla_days >= 0),
    max_sla_days integer NOT NULL CHECK (max_sla_days >= min_sla_days),
    status text NOT NULL DEFAULT 'active',
    PRIMARY KEY (carrier_code, service_level_code)
);

CREATE TABLE IF NOT EXISTS carrier.carrier_restrictions (
    restriction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    carrier_code text NOT NULL REFERENCES carrier.carriers(carrier_code) ON DELETE CASCADE,
    restriction_type text NOT NULL,
    restriction_value text NOT NULL,
    active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS pricing.freight_prices (
    freight_price_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id text NOT NULL,
    carrier_code text NOT NULL,
    service_level_code text NOT NULL,
    package_hash text NOT NULL,
    gross_cost numeric(12,2) NOT NULL CHECK (gross_cost >= 0),
    subsidy_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (subsidy_amount >= 0),
    buyer_cost numeric(12,2) NOT NULL CHECK (buyer_cost >= 0),
    currency char(3) NOT NULL DEFAULT 'BRL',
    calculated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pricing.subsidy_rules (
    subsidy_rule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid,
    category text,
    promotion_code text,
    subsidy_type text NOT NULL,
    subsidy_value numeric(12,2) NOT NULL CHECK (subsidy_value >= 0),
    starts_at timestamptz NOT NULL,
    ends_at timestamptz,
    active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS order_domain.orders (
    order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_id uuid NOT NULL UNIQUE,
    buyer_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    shipping_promise_id text NOT NULL,
    route_id text,
    carrier_code text,
    service_level_code text,
    origin_node_id uuid,
    promised_delivery_date date,
    destination jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'created',
    total_amount numeric(12,2) NOT NULL CHECK (total_amount >= 0),
    currency char(3) NOT NULL DEFAULT 'BRL',
    correlation_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz
);

CREATE TABLE IF NOT EXISTS order_domain.order_items (
    order_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES order_domain.orders(order_id) ON DELETE CASCADE,
    sku_id uuid NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE IF NOT EXISTS order_domain.order_packages (
    package_id text PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES order_domain.orders(order_id) ON DELETE CASCADE,
    weight_kg numeric(10,3) NOT NULL CHECK (weight_kg >= 0),
    height_cm numeric(10,2) NOT NULL CHECK (height_cm >= 0),
    width_cm numeric(10,2) NOT NULL CHECK (width_cm >= 0),
    length_cm numeric(10,2) NOT NULL CHECK (length_cm >= 0)
);

CREATE TABLE IF NOT EXISTS order_domain.order_package_items (
    package_id text NOT NULL REFERENCES order_domain.order_packages(package_id) ON DELETE CASCADE,
    sku_id uuid NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (package_id, sku_id)
);

CREATE TABLE IF NOT EXISTS order_domain.order_saga_states (
    order_id uuid PRIMARY KEY REFERENCES order_domain.orders(order_id) ON DELETE CASCADE,
    current_step text NOT NULL,
    status text NOT NULL,
    compensation_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    last_error text,
    version integer NOT NULL DEFAULT 1,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment.payment_authorizations (
    payment_authorization_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    buyer_id uuid,
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    currency char(3) NOT NULL DEFAULT 'BRL',
    payment_method text NOT NULL,
    provider text NOT NULL,
    provider_authorization_id text,
    status text NOT NULL DEFAULT 'pending',
    rejection_code text,
    authorized_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment.payment_captures (
    payment_capture_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_authorization_id uuid NOT NULL REFERENCES payment.payment_authorizations(payment_authorization_id),
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    status text NOT NULL DEFAULT 'pending',
    provider_capture_id text,
    captured_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment.refunds (
    refund_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_capture_id uuid REFERENCES payment.payment_captures(payment_capture_id),
    order_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    reason text NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    provider_refund_id text,
    refunded_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shipment.shipments (
    shipment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL UNIQUE,
    buyer_id uuid NOT NULL,
    seller_id uuid NOT NULL,
    carrier_code text NOT NULL,
    service_level_code text NOT NULL,
    external_shipment_id text,
    tracking_code text UNIQUE,
    label_object_key text,
    estimated_delivery_date date,
    status text NOT NULL DEFAULT 'created',
    cancellation_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz
);

CREATE TABLE IF NOT EXISTS shipment.shipment_volumes (
    shipment_volume_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id uuid NOT NULL REFERENCES shipment.shipments(shipment_id) ON DELETE CASCADE,
    package_id text NOT NULL,
    weight_kg numeric(10,3) NOT NULL CHECK (weight_kg >= 0),
    height_cm numeric(10,2) NOT NULL CHECK (height_cm >= 0),
    width_cm numeric(10,2) NOT NULL CHECK (width_cm >= 0),
    length_cm numeric(10,2) NOT NULL CHECK (length_cm >= 0),
    UNIQUE (shipment_id, package_id)
);

CREATE TABLE IF NOT EXISTS shipment.shipment_volume_items (
    shipment_volume_id uuid NOT NULL REFERENCES shipment.shipment_volumes(shipment_volume_id) ON DELETE CASCADE,
    sku_id uuid NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (shipment_volume_id, sku_id)
);

CREATE TABLE IF NOT EXISTS tracking.tracking_statuses (
    shipment_id uuid PRIMARY KEY,
    order_id uuid NOT NULL,
    buyer_id uuid NOT NULL,
    tracking_code text NOT NULL UNIQUE,
    carrier_code text NOT NULL,
    current_status text NOT NULL,
    estimated_delivery_date date,
    last_status_date timestamptz NOT NULL,
    exception_code text,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tracking.tracking_timeline (
    tracking_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id uuid NOT NULL,
    order_id uuid NOT NULL,
    tracking_code text NOT NULL,
    carrier_code text NOT NULL,
    previous_status text,
    current_status text NOT NULL,
    status_date timestamptz NOT NULL,
    exception_code text,
    raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (shipment_id, current_status, status_date)
);

CREATE TABLE IF NOT EXISTS notification.notification_plans (
    notification_plan_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_event_id uuid NOT NULL,
    event_type text NOT NULL,
    recipient_type text NOT NULL,
    recipient_id uuid NOT NULL,
    channel text NOT NULL,
    subject text,
    content jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'planned',
    planned_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification.notification_logs (
    notification_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_plan_id uuid REFERENCES notification.notification_plans(notification_plan_id),
    provider text,
    provider_message_id text,
    status text NOT NULL DEFAULT 'queued',
    attempts integer NOT NULL DEFAULT 0,
    last_error text,
    sent_at timestamptz,
    delivered_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit.audit_entries (
    entry_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL UNIQUE,
    event_type text NOT NULL,
    schema_version text NOT NULL,
    correlation_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL,
    producer text NOT NULL,
    topic text NOT NULL,
    partition integer,
    offset_value bigint,
    payload jsonb NOT NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_visibility.order_journey (
    id uuid PRIMARY KEY,
    order_id uuid NULL,
    checkout_id uuid NULL,
    buyer_id uuid NULL,
    seller_id uuid NULL,

    current_status varchar(80) NOT NULL,
    current_step varchar(120) NOT NULL,

    last_event_id uuid NULL,
    last_event_type varchar(120) NULL,
    last_event_at timestamptz NULL,

    -- Not a uuid: producers fall back to HttpContext.TraceIdentifier (e.g.
    -- "0HNMNNLB70E9S:00000043") as correlationId when no X-Correlation-Id header was sent.
    correlation_id varchar(200) NOT NULL,
    root_trace_id varchar(64) NULL,

    has_error boolean NOT NULL DEFAULT false,
    error_reason text NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_order_journey_order_id
    ON order_visibility.order_journey (order_id) WHERE order_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_journey_checkout_id
    ON order_visibility.order_journey (checkout_id) WHERE checkout_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_journey_correlation_id
    ON order_visibility.order_journey (correlation_id);
CREATE INDEX IF NOT EXISTS ix_order_journey_current_status
    ON order_visibility.order_journey (current_status);
CREATE INDEX IF NOT EXISTS ix_order_journey_updated_at
    ON order_visibility.order_journey (updated_at);

CREATE TABLE IF NOT EXISTS order_visibility.order_journey_events (
    id uuid PRIMARY KEY,
    journey_id uuid NOT NULL REFERENCES order_visibility.order_journey (id),

    order_id uuid NULL,
    checkout_id uuid NULL,

    event_id uuid NOT NULL,
    event_type varchar(120) NOT NULL,
    topic varchar(160) NOT NULL,
    partition integer NULL,
    offset_value bigint NULL,

    service_name varchar(120) NULL,

    status_before varchar(80) NULL,
    status_after varchar(80) NULL,

    correlation_id varchar(200) NOT NULL,
    trace_id varchar(64) NULL,
    span_id varchar(32) NULL,

    occurred_at timestamptz NOT NULL,
    consumed_at timestamptz NOT NULL DEFAULT now(),

    payload_json jsonb NOT NULL,

    UNIQUE (event_id)
);

CREATE INDEX IF NOT EXISTS ix_order_journey_events_order_id
    ON order_visibility.order_journey_events (order_id);
CREATE INDEX IF NOT EXISTS ix_order_journey_events_checkout_id
    ON order_visibility.order_journey_events (checkout_id);
CREATE INDEX IF NOT EXISTS ix_order_journey_events_correlation_id
    ON order_visibility.order_journey_events (correlation_id);
CREATE INDEX IF NOT EXISTS ix_order_journey_events_event_type
    ON order_visibility.order_journey_events (event_type);
CREATE INDEX IF NOT EXISTS ix_order_journey_events_occurred_at
    ON order_visibility.order_journey_events (occurred_at);

-- Owned by MarketplaceAdmin.Bff (openspec/changes/admin-backoffice). The BFF never writes to
-- any other schema; this is the only table it owns.
CREATE TABLE IF NOT EXISTS admin_bff.admin_audit_log (
    id uuid PRIMARY KEY,
    admin_user_id varchar(200) NOT NULL,
    action varchar(200) NOT NULL,
    entity_type varchar(200) NOT NULL,
    entity_id varchar(200) NOT NULL,
    before_json jsonb NULL,
    after_json jsonb NULL,
    correlation_id varchar(100) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_admin_audit_log_created_at
    ON admin_bff.admin_audit_log (created_at);
CREATE INDEX IF NOT EXISTS ix_admin_audit_log_entity
    ON admin_bff.admin_audit_log (entity_type, entity_id);

CREATE TABLE IF NOT EXISTS checkout.idempotency_keys (
    idempotency_key uuid PRIMARY KEY,
    resource_type text NOT NULL,
    resource_id text,
    request_hash text NOT NULL,
    response_payload jsonb,
    status_code integer,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_domain.idempotency_keys (LIKE checkout.idempotency_keys INCLUDING ALL);
CREATE TABLE IF NOT EXISTS inventory.idempotency_keys (LIKE checkout.idempotency_keys INCLUDING ALL);
CREATE TABLE IF NOT EXISTS fulfillment.idempotency_keys (LIKE checkout.idempotency_keys INCLUDING ALL);
CREATE TABLE IF NOT EXISTS payment.idempotency_keys (LIKE checkout.idempotency_keys INCLUDING ALL);

CREATE TABLE IF NOT EXISTS checkout.inbox_messages (
    event_id uuid PRIMARY KEY,
    event_type text NOT NULL,
    topic text NOT NULL,
    correlation_id uuid,
    status text NOT NULL DEFAULT 'pending',
    payload jsonb NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    error_message text
);

CREATE TABLE IF NOT EXISTS checkout.outbox_messages (
    message_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL UNIQUE,
    topic text NOT NULL,
    event_type text NOT NULL,
    schema_version text NOT NULL DEFAULT '1.0',
    correlation_id uuid NOT NULL,
    producer text NOT NULL,
    payload jsonb NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    attempts integer NOT NULL DEFAULT 0,
    next_retry_at timestamptz,
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_error text
);

CREATE TABLE IF NOT EXISTS shipping_promise.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS shipping_promise.outbox_messages (LIKE checkout.outbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS inventory.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS fulfillment.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS order_domain.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS order_domain.outbox_messages (LIKE checkout.outbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS payment.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS payment.outbox_messages (LIKE checkout.outbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS shipment.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS shipment.outbox_messages (LIKE checkout.outbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS tracking.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS tracking.outbox_messages (LIKE checkout.outbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS notification.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);
CREATE TABLE IF NOT EXISTS audit.inbox_messages (LIKE checkout.inbox_messages INCLUDING ALL);

CREATE INDEX IF NOT EXISTS idx_checkout_checkouts_buyer_id ON checkout.checkouts (buyer_id);
CREATE INDEX IF NOT EXISTS idx_checkout_items_checkout_id ON checkout.checkout_items (checkout_id);
CREATE INDEX IF NOT EXISTS idx_shipping_promises_checkout_id ON shipping_promise.shipping_promises (checkout_id);
CREATE INDEX IF NOT EXISTS idx_product_search_text ON product_search.product_index USING gin (to_tsvector('portuguese', searchable_text));
CREATE INDEX IF NOT EXISTS idx_inventory_balances_lookup ON inventory.inventory_balances (seller_id, sku_id, fulfillment_center_id);
CREATE INDEX IF NOT EXISTS idx_inventory_reservations_order_id ON inventory.inventory_reservations (order_id);
CREATE INDEX IF NOT EXISTS idx_capacity_windows_fc_time ON fulfillment.capacity_windows (fulfillment_center_id, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_routes_lookup ON routing.routes (origin_node_id, destination_zip_code, mode);
CREATE INDEX IF NOT EXISTS idx_freight_prices_lookup ON pricing.freight_prices (route_id, carrier_code, service_level_code);
CREATE INDEX IF NOT EXISTS idx_orders_buyer_id ON order_domain.orders (buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON order_domain.orders (status);
CREATE INDEX IF NOT EXISTS idx_payment_authorizations_order_id ON payment.payment_authorizations (order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_order_id ON shipment.shipments (order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_tracking_code ON shipment.shipments (tracking_code);
CREATE INDEX IF NOT EXISTS idx_tracking_timeline_shipment_date ON tracking.tracking_timeline (shipment_id, status_date);
CREATE INDEX IF NOT EXISTS idx_notification_plans_event ON notification.notification_plans (source_event_id, event_type);
CREATE INDEX IF NOT EXISTS idx_audit_entries_correlation_id ON audit.audit_entries (correlation_id);
CREATE INDEX IF NOT EXISTS idx_audit_entries_event_type ON audit.audit_entries (event_type);



-- ============================================================================
-- Canonical seed data (from logistica-envios-seed.sql)
-- ============================================================================

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



-- ============================================================================
-- EF Core compatibility schema (from logistica-envios-ef-compat.sql)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Compatibility layer for the actual EF Core DbContexts in the local microservice repos.
-- It keeps the canonical architecture schema intact and adds the tables/columns that
-- the current service implementations expect through EF mappings and conventions.

-- CheckoutService
-- Note: CheckoutRepository/ShippingPromiseProjectionRepository are plain Dapper
-- repositories issuing unquoted (snake_case, folded to lowercase) SQL, not an EF Core
-- DbContext. Compatibility columns therefore must be unquoted lowercase, since a quoted
-- PascalCase column (e.g. "Id") is a distinct column from an unquoted one (id) in Postgres.
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS shipping_mode text DEFAULT '';
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS carrier text DEFAULT '';
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS estimated_delivery_date date;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS items_total numeric(18,2) DEFAULT 0;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS shipping_cost numeric(18,2) DEFAULT 0;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS idempotency_key text DEFAULT gen_random_uuid()::text;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS confirmation_idempotency_key text;
ALTER TABLE checkout.checkouts ADD COLUMN IF NOT EXISTS payment_intent_id text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_checkouts_id ON checkout.checkouts (id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_checkouts_idempotency_key ON checkout.checkouts (idempotency_key);

ALTER TABLE checkout.checkout_items ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.checkout_items ALTER COLUMN seller_id DROP NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_items_id ON checkout.checkout_items (id);
-- checkout_items.checkout_id is populated by the repository with checkouts.id (not the
-- canonical checkout_id), so the FK must point at the compat id column instead. The
-- pre-existing golden-path checkout row got a random `id` from the volatile default above
-- (unrelated to its checkout_id), which would break its own checkout_item's FK — backfill it
-- to match, the same way product_catalog.products backfills its compat columns below.
UPDATE checkout.checkouts SET id = checkout_id
WHERE checkout_id = '55555555-5555-5555-5555-555555555555';
ALTER TABLE checkout.checkout_items DROP CONSTRAINT IF EXISTS checkout_items_checkout_id_fkey;
ALTER TABLE checkout.checkout_items ADD CONSTRAINT checkout_items_checkout_id_fkey
    FOREIGN KEY (checkout_id) REFERENCES checkout.checkouts (id) ON DELETE CASCADE;

-- Note: ShippingPromiseProjectionRepository is Dapper too (same unquoted-lowercase
-- requirement as CheckoutRepository above). checkout_id, promise_id, mode,
-- estimated_delivery_date and cost already exist as lowercase columns on the canonical
-- table; only the columns below are actually missing.
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS event_id uuid DEFAULT gen_random_uuid();
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS correlation_id text DEFAULT '';
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS carrier text DEFAULT '';
ALTER TABLE checkout.shipping_promise_projections ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
-- the repository never supplies buyer_id/seller_id/source/carrier_code (they aren't part
-- of the ShippingPromiseProjection domain model — carrier is stored in "carrier" instead
-- of "carrier_code"), so they can't stay NOT NULL without a default.
ALTER TABLE checkout.shipping_promise_projections ALTER COLUMN buyer_id DROP NOT NULL;
ALTER TABLE checkout.shipping_promise_projections ALTER COLUMN seller_id DROP NOT NULL;
ALTER TABLE checkout.shipping_promise_projections ALTER COLUMN source DROP NOT NULL;
ALTER TABLE checkout.shipping_promise_projections ALTER COLUMN carrier_code DROP NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_checkout_shipping_promise_projections_id ON checkout.shipping_promise_projections (id);
-- checkout_id is populated by the repository with checkouts.id (the compat column), not
-- the canonical checkout_id, so the FK must point at the compat id column instead.
ALTER TABLE checkout.shipping_promise_projections DROP CONSTRAINT IF EXISTS shipping_promise_projections_checkout_id_fkey;
ALTER TABLE checkout.shipping_promise_projections ADD CONSTRAINT shipping_promise_projections_checkout_id_fkey
    FOREIGN KEY (checkout_id) REFERENCES checkout.checkouts (id) ON DELETE CASCADE;

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
ALTER TABLE product_catalog.products ADD COLUMN IF NOT EXISTS image_url text;
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

-- InventoryService (admin stock adjustments, openspec/changes/admin-backoffice).
-- Distinct from the canonical inventory.inventory_adjustments table above: that table isn't
-- read/written by any current service code (same situation as product_search.product_index),
-- so this follows the inventory_items precedent of adding a fresh compat table that matches
-- the EF Core entity (StockMovement) exactly, rather than retrofitting the unused one.
CREATE TABLE IF NOT EXISTS inventory.stock_movements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id uuid NOT NULL,
    sku_id uuid NOT NULL,
    fulfillment_center_id uuid NOT NULL,
    quantity_delta integer NOT NULL,
    reason text NOT NULL,
    description text,
    idempotency_key varchar(200) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_stock_movements_idempotency_key ON inventory.stock_movements (idempotency_key);
CREATE INDEX IF NOT EXISTS ix_inventory_stock_movements_lookup ON inventory.stock_movements (seller_id, sku_id, fulfillment_center_id);

ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS checkout_id uuid;
ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS seller_id uuid;
ALTER TABLE inventory.inventory_reservations ADD COLUMN IF NOT EXISTS idempotency_key text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_reservations_id ON inventory.inventory_reservations (id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_reservations_idempotency_key ON inventory.inventory_reservations (idempotency_key) WHERE idempotency_key IS NOT NULL;

ALTER TABLE inventory.inventory_reservation_items ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE inventory.inventory_reservation_items ADD COLUMN IF NOT EXISTS reservation_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_reservation_items_id ON inventory.inventory_reservation_items (id);
-- InventoryDbContext's OwnsMany mapping for ReservationItem has no seller_id property (the
-- seller is tracked once on the parent InventoryReservation, not per item), so EF never
-- populates this canonical NOT NULL column on insert.
ALTER TABLE inventory.inventory_reservation_items ALTER COLUMN seller_id DROP NOT NULL;
-- InventoryDbContext keys InventoryReservation by the compat `id` column (not the
-- canonical `reservation_id` PK) and uses that same value as the owned items' FK, so the
-- FK must reference `id` here too -- same pattern as checkout_items_checkout_id_fkey above.
-- The pre-existing golden-path reservation row got a random `id` from the volatile default
-- above (unrelated to its reservation_id), which would break its own reservation_item's FK
-- once repointed -- backfill it to match, same as checkout.checkouts above.
UPDATE inventory.inventory_reservations SET id = reservation_id
WHERE reservation_id = '44444444-4444-4444-4444-444444444443';
ALTER TABLE inventory.inventory_reservation_items DROP CONSTRAINT IF EXISTS inventory_reservation_items_reservation_id_fkey;
ALTER TABLE inventory.inventory_reservation_items ADD CONSTRAINT inventory_reservation_items_reservation_id_fkey
    FOREIGN KEY (reservation_id) REFERENCES inventory.inventory_reservations (id) ON DELETE CASCADE;

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
-- CapacityManagementService.CreateAsync (openspec/changes/admin-backoffice) inserts new rows
-- through the EF-mapped ("Code", "Name", ...) columns only. The canonical lowercase columns
-- below have no default and would otherwise reject the insert with a NOT NULL violation, the
-- same problem shipping_promise_projections had above with buyer_id/seller_id/source/carrier_code.
ALTER TABLE fulfillment.fulfillment_centers ALTER COLUMN code DROP NOT NULL;
ALTER TABLE fulfillment.fulfillment_centers ALTER COLUMN name DROP NOT NULL;
ALTER TABLE fulfillment.fulfillment_centers ALTER COLUMN zip_code DROP NOT NULL;
ALTER TABLE fulfillment.fulfillment_centers ALTER COLUMN city DROP NOT NULL;
ALTER TABLE fulfillment.fulfillment_centers ALTER COLUMN state DROP NOT NULL;
ALTER TABLE fulfillment.fulfillment_centers ALTER COLUMN daily_cutoff DROP NOT NULL;

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
-- capacity_window_id is the canonical FK to fulfillment.capacity_windows, a concept the
-- EF Core app never uses (it tracks capacity via the compat capacity_slots table instead).
-- FulfillmentDbContext has no mapping for it, so every EF insert leaves it unset; without
-- dropping NOT NULL here, CapacityReservationService.CreateAsync would violate this
-- constraint on every reservation.
ALTER TABLE fulfillment.capacity_reservations ALTER COLUMN capacity_window_id DROP NOT NULL;

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
CREATE UNIQUE INDEX IF NOT EXISTS ux_center_operation_schedules_fc_date_mode ON fulfillment.center_operation_schedules ("FulfillmentCenterId", "OperationDate", "Mode");
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
    service_level_code text NOT NULL DEFAULT '',
    mode text NOT NULL,
    transit_minutes integer NOT NULL,
    maximum_weight_kg numeric(10,3) NOT NULL DEFAULT 30,
    maximum_cubic_weight_kg numeric(10,3) NOT NULL DEFAULT 30,
    supports_fragile_items boolean NOT NULL DEFAULT true,
    supports_restricted_items boolean NOT NULL DEFAULT true,
    status text NOT NULL DEFAULT 'Active',
    version bigint NOT NULL DEFAULT 1
);
-- service_level_code was added after this table's original release; ADD COLUMN keeps
-- re-application idempotent on databases created before this column existed. It must
-- carry the CarrierService carrier_service_levels.code for the lane's first leg (e.g.
-- "same_day", "standard") -- RoutingService.Application.RouteSearchService forwards only
-- the first leg's ServiceLevelCode to ShippingPromiseService, which passes it verbatim to
-- CarrierService and ShippingPricingService for an exact-match lookup.
ALTER TABLE routing.logistics_lanes ADD COLUMN IF NOT EXISTS service_level_code text NOT NULL DEFAULT '';
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
-- CarrierAdministrationEndpoints.CreateCarrier only populates the EF-mapped ("Code", "Name",
-- ...) columns (openspec/changes/admin-backoffice); canonical name has no default, same
-- NOT NULL problem as fulfillment.fulfillment_centers/code/name above.
ALTER TABLE carrier.carriers ALTER COLUMN name DROP NOT NULL;
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
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS confirmed_at timestamptz;
ALTER TABLE order_domain.orders ADD COLUMN IF NOT EXISTS cancellation_reason text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_orders_id ON order_domain.orders (id);

ALTER TABLE order_domain.order_items ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE order_domain.order_items ADD COLUMN IF NOT EXISTS title text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_order_items_id ON order_domain.order_items (id);

ALTER TABLE order_domain.inbox_messages ALTER COLUMN event_id SET DEFAULT gen_random_uuid();
ALTER TABLE order_domain.inbox_messages ADD COLUMN IF NOT EXISTS message_id uuid DEFAULT gen_random_uuid();
ALTER TABLE order_domain.inbox_messages ADD COLUMN IF NOT EXISTS message_type text;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_inbox_messages_message_id ON order_domain.inbox_messages (message_id);
-- OrderService's InboxMessage/OutboxMessage EF Core entities use a simpler
-- (message_id/message_type/topic/payload/processed_at) shape than the canonical
-- envelope columns copied via `LIKE checkout.*_messages INCLUDING ALL` below, so those
-- envelope-only columns (event_type/topic/payload on inbox, event_id/event_type/
-- correlation_id/producer on outbox) are relaxed to nullable for this schema only.
ALTER TABLE order_domain.inbox_messages ALTER COLUMN event_type DROP NOT NULL;
ALTER TABLE order_domain.inbox_messages ALTER COLUMN topic DROP NOT NULL;
ALTER TABLE order_domain.inbox_messages ALTER COLUMN payload DROP NOT NULL;

ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS message_type text;
ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS aggregate_key text;
ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE order_domain.outbox_messages ADD COLUMN IF NOT EXISTS processed_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_order_domain_outbox_messages_id ON order_domain.outbox_messages (id);
ALTER TABLE order_domain.outbox_messages ALTER COLUMN event_id DROP NOT NULL;
ALTER TABLE order_domain.outbox_messages ALTER COLUMN event_type DROP NOT NULL;
ALTER TABLE order_domain.outbox_messages ALTER COLUMN correlation_id DROP NOT NULL;
ALTER TABLE order_domain.outbox_messages ALTER COLUMN producer DROP NOT NULL;

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
-- TrackingService's EF InboxMessage entity only populates message_id/message_type/processed_at;
-- these inherited-from-checkout.inbox_messages columns must not block admin-triggered event inserts.
ALTER TABLE tracking.inbox_messages ALTER COLUMN event_type DROP NOT NULL;
ALTER TABLE tracking.inbox_messages ALTER COLUMN topic DROP NOT NULL;
ALTER TABLE tracking.inbox_messages ALTER COLUMN payload DROP NOT NULL;
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS message_type text;
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS aggregate_key text;
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;
ALTER TABLE tracking.outbox_messages ADD COLUMN IF NOT EXISTS processed_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS ux_tracking_outbox_messages_id ON tracking.outbox_messages (id);
-- Same dual-schema trap as inbox_messages above: TrackingService's outbox writer only populates
-- id/message_type/aggregate_key/next_attempt_at/processed_at, not the inherited legacy columns.
ALTER TABLE tracking.outbox_messages ALTER COLUMN event_id DROP NOT NULL;
ALTER TABLE tracking.outbox_messages ALTER COLUMN topic DROP NOT NULL;
ALTER TABLE tracking.outbox_messages ALTER COLUMN event_type DROP NOT NULL;
ALTER TABLE tracking.outbox_messages ALTER COLUMN correlation_id DROP NOT NULL;
ALTER TABLE tracking.outbox_messages ALTER COLUMN producer DROP NOT NULL;
ALTER TABLE tracking.outbox_messages ALTER COLUMN payload DROP NOT NULL;

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



-- ============================================================================
-- EF Core compatibility seed data (from logistica-envios-ef-compat-seed.sql)
-- ============================================================================

BEGIN;

UPDATE product_catalog.products
SET
    id = COALESCE(id, gen_random_uuid()),
    seller_id = COALESCE(seller_id, '22222222-2222-2222-2222-222222222222'),
    price = CASE WHEN price = 0 THEN 1299.90 ELSE price END,
    is_fragile = true,
    is_restricted = false,
    -- Galaxy J SC-02F Lapis Blue 1.jpg, author: Qurren, license: CC BY-SA 3.0
    image_url = COALESCE(image_url, 'https://upload.wikimedia.org/wikipedia/commons/7/7e/Galaxy_J_SC-02F_Lapis_Blue_1.jpg')
WHERE sku_id = '11111111-1111-1111-1111-111111111111';

-- ProductCatalogService reads id/seller_id/price/is_fragile/is_restricted from this same
-- table (see ProductRepository.cs) alongside the canonical columns above. The fone product
-- was seeded canonically but never got its compat columns backfilled until now.
UPDATE product_catalog.products
SET
    id = COALESCE(id, gen_random_uuid()),
    seller_id = COALESCE(seller_id, '22222222-2222-2222-2222-222222222222'),
    price = CASE WHEN price = 0 THEN 129.90 ELSE price END,
    is_fragile = false,
    is_restricted = true,
    -- Powerbeats Pro 2 Black model - 1.jpg, author: Kyu3a, license: CC BY-SA 4.0
    image_url = COALESCE(image_url, 'https://upload.wikimedia.org/wikipedia/commons/a/ae/Powerbeats_Pro_2_Black_model_-_1.jpg')
WHERE sku_id = '11111111-1111-1111-1111-111111111112';

-- 18 additional products (sku_id continues the existing 11111111-...-1111111111XX prefix)
-- covering multiple categories/weights, three battery-restricted items, and one product
-- >= 10kg used to exercise the heavier routing/carrier/pricing lanes added below.
-- id is set equal to sku_id here for simplicity (they are independent columns; nothing
-- requires them to differ).
-- Image sourcing: curated Wikimedia Commons URLs baked in at seed time (see design.md,
-- openspec/changes/product-images). Public domain/CC0 preferred; author+license recorded
-- as a comment for each row where the image is CC-BY/CC-BY-SA.
INSERT INTO product_catalog.products (
    sku_id, title, category, weight_kg, height_cm, width_cm, length_cm, status, created_at, updated_at,
    id, seller_id, price, is_fragile, is_restricted, image_url
) VALUES
    -- image: MSI Gaming Laptop on wood floor.jpg, author: Kurt Kaiser, license: CC0
    ('11111111-1111-1111-1111-111111111113', 'Notebook Gamer Demo', 'electronics', 2.800, 5.00, 40.00, 30.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111113', '22222222-2222-2222-2222-222222222222', 4599.00, true, false,
     'https://upload.wikimedia.org/wikipedia/commons/c/c9/MSI_Gaming_Laptop_on_wood_floor.jpg'),
    -- image: Powerbank integrated charging controller with LEDs and heat sink (Selectec HYT-Q3).jpg, author: KalteSonne, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111114', 'Carregador Portatil Demo', 'electronics', 0.200, 3.00, 8.00, 15.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111114', '22222222-2222-2222-2222-222222222222', 89.90, false, true,
     'https://upload.wikimedia.org/wikipedia/commons/8/89/Powerbank_integrated_charging_controller_with_LEDs_and_heat_sink_%28Selectec_HYT-Q3%29.jpg'),
    -- image: Electric Brew Coffee Maker.jpg, author: GautamSudhanshu, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111115', 'Cafeteira Eletrica Demo', 'home', 3.500, 30.00, 25.00, 35.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111115', '22222222-2222-2222-2222-222222222222', 349.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/0/0b/Electric_Brew_Coffee_Maker.jpg'),
    -- image: Cooking pots.jpg, author: Poecus, license: Public domain
    ('11111111-1111-1111-1111-111111111116', 'Conjunto de Panelas Demo', 'home', 4.200, 20.00, 40.00, 40.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111116', '22222222-2222-2222-2222-222222222222', 599.90, true, false,
     'https://upload.wikimedia.org/wikipedia/commons/6/65/Cooking_pots.jpg'),
    -- image: White desk light.jpg, author: Thidapa, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111117', 'Luminaria de Mesa Demo', 'home', 1.100, 45.00, 15.00, 15.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111117', '22222222-2222-2222-2222-222222222222', 179.90, true, false,
     'https://upload.wikimedia.org/wikipedia/commons/0/09/White_desk_light.jpg'),
    -- image: Dragon Ball action toy in india.jpg, author: Suyash Dwivedi, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111118', 'Boneco de Acao Colecionavel Demo', 'toys', 0.300, 10.00, 8.00, 25.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111118', '22222222-2222-2222-2222-222222222222', 129.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/2/2f/Dragon_Ball_action_toy_in_india.jpg'),
    -- image: Trefl Puzzles 1000 pieces.jpg, author: Mosbatho, license: CC BY 4.0
    ('11111111-1111-1111-1111-111111111119', 'Quebra-Cabeca 1000 Pecas Demo', 'toys', 0.700, 30.00, 20.00, 5.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111119', '22222222-2222-2222-2222-222222222222', 79.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/9/92/Trefl_Puzzles_1000_pieces.jpg'),
    -- image: On Clouds running shoes.jpg, author: Goodreg3, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111120', 'Tenis Esportivo Demo', 'fashion', 0.900, 12.00, 20.00, 30.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111120', '22222222-2222-2222-2222-222222222222', 349.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/8/89/On_Clouds_running_shoes.jpg'),
    -- image: Windbreaker Jacket, Hood Outside.jpg, author: Ingolfson, license: Public domain
    ('11111111-1111-1111-1111-111111111121', 'Jaqueta Corta-Vento Demo', 'fashion', 0.450, 5.00, 30.00, 40.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111121', '22222222-2222-2222-2222-222222222222', 219.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/4/46/Windbreaker_Jacket%2C_Hood_Outside.jpg'),
    -- image: HK backpack bag XD Design Bobby Urban grey September 2022 Px3 01.jpg, author: Hjfm 003, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111122', 'Mochila Executiva Demo', 'fashion', 0.850, 45.00, 30.00, 15.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111122', '22222222-2222-2222-2222-222222222222', 289.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/2/29/HK_backpack_bag_XD_Design_Bobby_Urban_grey_September_2022_Px3_01.jpg'),
    -- image: Old book bindings.jpg, author: Tom Murphy VII, license: CC BY-SA 3.0
    ('11111111-1111-1111-1111-111111111123', 'Livro Best-Seller Demo', 'books', 0.400, 20.00, 13.00, 3.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111123', '22222222-2222-2222-2222-222222222222', 59.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/8/87/Old_book_bindings.jpg'),
    -- image: Tactile picture books HP72 C.JPG, author: Anneli Salo, license: CC BY-SA 3.0
    ('11111111-1111-1111-1111-111111111124', 'Kit 3 Livros Infantis Demo', 'books', 0.900, 25.00, 18.00, 6.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111124', '22222222-2222-2222-2222-222222222222', 89.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/b/b9/Tactile_picture_books_HP72_C.JPG'),
    -- image: Molten soccer ball.jpg, author: Vee Satayamas, license: CC BY 4.0
    ('11111111-1111-1111-1111-111111111125', 'Bola de Futebol Demo', 'sports', 0.450, 22.00, 22.00, 22.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111125', '22222222-2222-2222-2222-222222222222', 129.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/d/d8/Molten_soccer_ball.jpg'),
    -- image: Colorful dumbbells of various sizes.jpg, author: Ser Amantio di Nicolao, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111126', 'Kit Halteres 10kg Demo', 'sports', 10.500, 20.00, 20.00, 40.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111126', '22222222-2222-2222-2222-222222222222', 249.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/f/f1/Colorful_dumbbells_of_various_sizes.jpg'),
    -- image: Czech Glass Perfume Bottle-1.jpg, author: Tangerineduel, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111127', 'Perfume Importado 100ml Demo', 'beauty', 0.300, 15.00, 8.00, 8.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111127', '22222222-2222-2222-2222-222222222222', 459.90, true, false,
     'https://upload.wikimedia.org/wikipedia/commons/0/09/Czech_Glass_Perfume_Bottle-1.jpg'),
    -- image: Makeup cosmetics.jpg, author: Bairavi Arjunan3, license: CC BY-SA 4.0
    ('11111111-1111-1111-1111-111111111128', 'Kit Maquiagem Completo Demo', 'beauty', 0.500, 20.00, 15.00, 10.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111128', '22222222-2222-2222-2222-222222222222', 199.90, false, false,
     'https://upload.wikimedia.org/wikipedia/commons/0/08/Makeup_cosmetics.jpg'),
    -- image: Power bank.JPG, author: Ilya Plekhanov, license: CC BY-SA 3.0
    ('11111111-1111-1111-1111-111111111129', 'Powerbank 20000mAh Demo', 'electronics', 0.400, 2.50, 8.00, 15.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111129', '22222222-2222-2222-2222-222222222222', 149.90, false, true,
     'https://upload.wikimedia.org/wikipedia/commons/7/7c/Power_bank.JPG'),
    -- image: Exotic Fruit Gift Basket (4461109309).jpg, author: Vegan Feast Catering, license: CC BY 2.0
    ('11111111-1111-1111-1111-111111111130', 'Cesta de Cafe da Manha Demo', 'grocery', 2.000, 25.00, 25.00, 15.00, 'Active', now(), now(),
     '11111111-1111-1111-1111-111111111130', '22222222-2222-2222-2222-222222222222', 179.90, true, false,
     'https://upload.wikimedia.org/wikipedia/commons/c/c7/Exotic_Fruit_Gift_Basket_%284461109309%29.jpg')
ON CONFLICT (sku_id) DO NOTHING;

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

-- InventoryService reads inventory.inventory_items exclusively (see InventoryRepository.cs);
-- inventory.inventory_balances is never queried. One row per remaining product at FC-SP-01.
INSERT INTO inventory.inventory_items (
    id, seller_id, sku_id, fulfillment_center_id, on_hand_quantity, reserved_quantity, updated_at
) VALUES
    ('44444444-4444-4444-4444-444444444452', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111112', '33333333-3333-3333-3333-333333333333', 80, 0, now()),
    ('44444444-4444-4444-4444-444444444453', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111113', '33333333-3333-3333-3333-333333333333', 15, 0, now()),
    ('44444444-4444-4444-4444-444444444454', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111114', '33333333-3333-3333-3333-333333333333', 60, 0, now()),
    ('44444444-4444-4444-4444-444444444455', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111115', '33333333-3333-3333-3333-333333333333', 20, 0, now()),
    ('44444444-4444-4444-4444-444444444456', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111116', '33333333-3333-3333-3333-333333333333', 18, 0, now()),
    ('44444444-4444-4444-4444-444444444457', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111117', '33333333-3333-3333-3333-333333333333', 30, 0, now()),
    ('44444444-4444-4444-4444-444444444458', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111118', '33333333-3333-3333-3333-333333333333', 40, 0, now()),
    ('44444444-4444-4444-4444-444444444459', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111119', '33333333-3333-3333-3333-333333333333', 35, 0, now()),
    ('44444444-4444-4444-4444-444444444460', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111120', '33333333-3333-3333-3333-333333333333', 45, 0, now()),
    ('44444444-4444-4444-4444-444444444461', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111121', '33333333-3333-3333-3333-333333333333', 25, 0, now()),
    ('44444444-4444-4444-4444-444444444462', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111122', '33333333-3333-3333-3333-333333333333', 22, 0, now()),
    ('44444444-4444-4444-4444-444444444463', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111123', '33333333-3333-3333-3333-333333333333', 100, 0, now()),
    ('44444444-4444-4444-4444-444444444464', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111124', '33333333-3333-3333-3333-333333333333', 60, 0, now()),
    ('44444444-4444-4444-4444-444444444465', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111125', '33333333-3333-3333-3333-333333333333', 50, 0, now()),
    ('44444444-4444-4444-4444-444444444466', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111126', '33333333-3333-3333-3333-333333333333', 12, 1, now()),
    ('44444444-4444-4444-4444-444444444467', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111127', '33333333-3333-3333-3333-333333333333', 28, 0, now()),
    ('44444444-4444-4444-4444-444444444468', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111128', '33333333-3333-3333-3333-333333333333', 33, 0, now()),
    ('44444444-4444-4444-4444-444444444469', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111129', '33333333-3333-3333-3333-333333333333', 40, 0, now()),
    ('44444444-4444-4444-4444-444444444470', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111130', '33333333-3333-3333-3333-333333333333', 24, 0, now())
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

-- CapacityRepository/OperationalCalendarRepository look up rows by exact OperationDate,
-- and OperationalCalendarService only scans 14 days ahead of "now" with no fallback — a
-- fixed literal date (the previous '2026-06-22' seed) goes stale the day after it's applied.
-- Seed a rolling 21-day window from CURRENT_DATE instead, so the script stays valid
-- whenever it's applied.
INSERT INTO fulfillment.capacity_slots (
    "Id", "FulfillmentCenterId", "OperationDate", "Mode",
    "TotalCapacityUnits", "ReservedCapacityUnits", "ConsumedCapacityUnits", "UpdatedAt"
)
SELECT
    gen_random_uuid(),
    '33333333-3333-3333-3333-333333333333',
    day::date,
    'Fulfillment',
    1000,
    0,
    0,
    now()
FROM generate_series(CURRENT_DATE, CURRENT_DATE + interval '21 days', interval '1 day') AS day
ON CONFLICT ("FulfillmentCenterId", "OperationDate", "Mode") DO NOTHING;

-- FulfillmentCenterService.CandidateSearchService.NormalizePostalCode strips the first 2
-- digits of the 8-digit CEP before comparing (covered by CandidateSearchServiceTests.cs:47,
-- e.g. "01310-100" -> 310100) — a DIFFERENT convention from routing.postal_coverages and
-- pricing.postal_zones below, which use the full 8-digit CEP as-is. This range must stay in
-- the 0-999999 space, not the previous 1000000-9999999 (which could never match).
INSERT INTO fulfillment.center_coverages (
    "Id", "FulfillmentCenterId", "PostalCodeFrom", "PostalCodeTo", "Mode", "Priority"
) VALUES
    (
        '33333333-3333-3333-3333-333333333342',
        '33333333-3333-3333-3333-333333333333',
        0,
        999999,
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
)
SELECT
    gen_random_uuid(),
    '33333333-3333-3333-3333-333333333333',
    day::date,
    'Fulfillment',
    true,
    '08:00',
    '14:00',
    '18:00'
FROM generate_series(CURRENT_DATE, CURRENT_DATE + interval '21 days', interval '1 day') AS day
ON CONFLICT ("FulfillmentCenterId", "OperationDate", "Mode") DO NOTHING;

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
    ),
    (
        '77777777-7777-7777-7777-777777777901',
        'LM-SP-057',
        'Last Mile Sao Paulo CEP 057',
        'Brasil Sudeste',
        'America/Sao_Paulo',
        'LastMileStation',
        10,
        true
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO routing.logistics_lanes (
    id, origin_node_id, destination_node_id, carrier_code, service_level_code, mode, transit_minutes,
    maximum_weight_kg, maximum_cubic_weight_kg, supports_fragile_items,
    supports_restricted_items, status, version
) VALUES
    (
        -- First leg of the FC -> hub -> LM-SP-ZS same_day route. ShippingPromiseApplicationService
        -- only reads the FIRST leg's carrier/service level code, so this row's service_level_code
        -- ('same_day') is what actually reaches CarrierService/ShippingPricingService for the whole
        -- route -- it must match carrier.carrier_service_levels.code for CARRIER_1.
        '77777777-7777-7777-7777-777777777783',
        '33333333-3333-3333-3333-333333333333',
        '77777777-7777-7777-7777-777777777771',
        'carrier_1',
        'same_day',
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
        'same_day',
        'LastMile',
        90,
        30,
        30,
        true,
        true,
        'Active',
        1
    ),
    (
        -- Direct FC -> destination lane (not via the hub): ShippingPromiseApplicationService
        -- only reads the FIRST leg's carrier code, so this must be a single-hop lane for
        -- carrier_2 to actually be the reported carrier for this destination. service_level_code
        -- ('standard') must match carrier.carrier_service_levels.code for CARRIER_2.
        '77777777-7777-7777-7777-777777777902',
        '33333333-3333-3333-3333-333333333333',
        '77777777-7777-7777-7777-777777777901',
        'carrier_2',
        'standard',
        'LastMile',
        75,
        30,
        30,
        true,
        true,
        'Active',
        1
    )
ON CONFLICT (id) DO NOTHING;

-- Backfills service_level_code for databases seeded before this column existed (the INSERT
-- above is skipped entirely by ON CONFLICT DO NOTHING on those installs).
UPDATE routing.logistics_lanes SET service_level_code = 'same_day'
WHERE id IN ('77777777-7777-7777-7777-777777777783', '77777777-7777-7777-7777-777777777784')
  AND service_level_code = '';
UPDATE routing.logistics_lanes SET service_level_code = 'standard'
WHERE id = '77777777-7777-7777-7777-777777777902'
  AND service_level_code = '';

-- Schedules originally only covered Monday, so any route search run on another day of the
-- week found nothing (see RoutingService/database/seed-route-333-to-05700000.sql, whose own
-- comments show it was tuned for one specific date/weekday). Cover all 7 days for every
-- lane so the seed stays usable regardless of when it's applied.
INSERT INTO routing.lane_schedules (
    id, logistics_lane_id, day_of_week, departure_time, is_active
) VALUES
    ('77777777-7777-7777-7777-777777777785', '77777777-7777-7777-7777-777777777783', 'Monday', '09:00', true),
    ('77777777-7777-7777-7777-777777777786', '77777777-7777-7777-7777-777777777784', 'Monday', '11:00', true),
    ('77777777-7777-7777-7777-777777777930', '77777777-7777-7777-7777-777777777783', 'Tuesday', '09:00', true),
    ('77777777-7777-7777-7777-777777777931', '77777777-7777-7777-7777-777777777783', 'Wednesday', '09:00', true),
    ('77777777-7777-7777-7777-777777777932', '77777777-7777-7777-7777-777777777783', 'Thursday', '09:00', true),
    ('77777777-7777-7777-7777-777777777933', '77777777-7777-7777-7777-777777777783', 'Friday', '09:00', true),
    ('77777777-7777-7777-7777-777777777934', '77777777-7777-7777-7777-777777777783', 'Saturday', '09:00', true),
    ('77777777-7777-7777-7777-777777777935', '77777777-7777-7777-7777-777777777783', 'Sunday', '09:00', true),
    ('77777777-7777-7777-7777-777777777940', '77777777-7777-7777-7777-777777777784', 'Tuesday', '11:00', true),
    ('77777777-7777-7777-7777-777777777941', '77777777-7777-7777-7777-777777777784', 'Wednesday', '11:00', true),
    ('77777777-7777-7777-7777-777777777942', '77777777-7777-7777-7777-777777777784', 'Thursday', '11:00', true),
    ('77777777-7777-7777-7777-777777777943', '77777777-7777-7777-7777-777777777784', 'Friday', '11:00', true),
    ('77777777-7777-7777-7777-777777777944', '77777777-7777-7777-7777-777777777784', 'Saturday', '11:00', true),
    ('77777777-7777-7777-7777-777777777945', '77777777-7777-7777-7777-777777777784', 'Sunday', '11:00', true),
    ('77777777-7777-7777-7777-777777777910', '77777777-7777-7777-7777-777777777902', 'Monday', '09:30', true),
    ('77777777-7777-7777-7777-777777777911', '77777777-7777-7777-7777-777777777902', 'Tuesday', '09:30', true),
    ('77777777-7777-7777-7777-777777777912', '77777777-7777-7777-7777-777777777902', 'Wednesday', '09:30', true),
    ('77777777-7777-7777-7777-777777777913', '77777777-7777-7777-7777-777777777902', 'Thursday', '09:30', true),
    ('77777777-7777-7777-7777-777777777914', '77777777-7777-7777-7777-777777777902', 'Friday', '09:30', true),
    ('77777777-7777-7777-7777-777777777915', '77777777-7777-7777-7777-777777777902', 'Saturday', '09:30', true),
    ('77777777-7777-7777-7777-777777777916', '77777777-7777-7777-7777-777777777902', 'Sunday', '09:30', true)
ON CONFLICT (id) DO NOTHING;

-- RouteSearchService.NormalizePostalCode uses the full 8-digit CEP as a number (no digits
-- dropped) — the opposite convention from fulfillment.center_coverages above. Do not mix
-- the two: this range must stay in "full CEP" space (e.g. 5700000-5799999 for CEP 05700-000).
INSERT INTO routing.postal_coverages (
    id, destination_node_id, postal_code_from, postal_code_to, priority
) VALUES
    (
        '77777777-7777-7777-7777-777777777787',
        '77777777-7777-7777-7777-777777777772',
        1000000,
        9999999,
        1
    ),
    (
        '77777777-7777-7777-7777-777777777920',
        '77777777-7777-7777-7777-777777777901',
        5700000,
        5799999,
        1
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO routing.network_versions (region, version, updated_at)
VALUES ('Brasil Sudeste', 2, now())
ON CONFLICT (region) DO UPDATE SET version = EXCLUDED.version, updated_at = EXCLUDED.updated_at;

-- CarrierRepository.GetProfileAsync uppercases the incoming carrierCode before comparing
-- to carrier.carriers."Code" (Carrier.cs's own constructor also enforces ToUpperInvariant()
-- as a domain invariant). The seed previously stored 'carrier_1' in lowercase, which could
-- never match a normalized lookup — "Code" must be uppercase regardless of the (lowercase)
-- carrier_code strings used in routing.logistics_lanes, since those get uppercased too.
UPDATE carrier.carriers
SET
    "Id" = '88888888-8888-8888-8888-888888888800',
    "Code" = 'CARRIER_1',
    "Name" = 'Carrier Demo Express',
    "Status" = 'Active',
    "RequiresRealTimeValidation" = false
WHERE carrier_code = 'carrier_1';

-- 'correios' predates the compat backfill above and was missed; ICarrierRepository.ListAsync
-- (openspec/changes/admin-backoffice) reads every row unconditionally, so a NULL "Code"/"Name"
-- here throws InvalidCastException on materialization, not just fail an equality lookup.
UPDATE carrier.carriers
SET
    "Id" = gen_random_uuid(),
    "Code" = 'CORREIOS',
    "Name" = 'Correios',
    "Status" = 'Active',
    "RequiresRealTimeValidation" = false
WHERE carrier_code = 'correios';

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

-- Second carrier: same normalization rule applies, "Code" must be uppercase.
-- SupportsRestrictedItems = false here (vs. true above) so restriction differentiation is
-- observable when CarrierService is queried directly (see design.md — ShippingPromiseService
-- itself never reaches this check for restricted items, it short-circuits earlier).
INSERT INTO carrier.carriers (
    carrier_code, name, status, integration_type,
    "Id", "Code", "Name", "Status", "RequiresRealTimeValidation", "StatusUpdatedAt", "CreatedAt", "UpdatedAt"
) VALUES (
    'carrier_2',
    'Carrier Demo Standard',
    'active',
    'api',
    '88888888-8888-8888-8888-888888888810',
    'CARRIER_2',
    'Carrier Demo Standard',
    'Active',
    false,
    now(),
    now(),
    now()
)
ON CONFLICT (carrier_code) DO NOTHING;

INSERT INTO carrier.carrier_service_levels (
    "Id", "CarrierId", "Code", "Name", "Mode", "MaximumWeightKg",
    "MaximumCubicWeightKg", "SupportsFragileItems", "SupportsRestrictedItems",
    "Priority", "IsActive"
) VALUES
    (
        '88888888-8888-8888-8888-888888888811',
        '88888888-8888-8888-8888-888888888810',
        'standard',
        'Entrega padrao',
        'CARRIER',
        30,
        30,
        true,
        false,
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
        '88888888-8888-8888-8888-888888888812',
        '88888888-8888-8888-8888-888888888811',
        '33333333-3333-3333-3333-333333333333',
        '77777777-7777-7777-7777-777777777901',
        'America/Sao_Paulo',
        '14:00',
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true
    )
ON CONFLICT ("Id") DO NOTHING;

-- Convention: full 8-digit CEP as a number, same as routing.postal_coverages above (NOT the
-- fulfillment.center_coverages "drop first 2 digits" convention).
INSERT INTO pricing.postal_zones (
    "Id", "Code", "PostalCodeFrom", "PostalCodeTo", "IsRemoteArea", "Priority"
) VALUES
    (
        '99999999-9999-9999-9999-999999999981',
        'SP-CAPITAL',
        1000000,
        9999999,
        false,
        1
    ),
    (
        '99999999-9999-9999-9999-999999999985',
        'SP-057',
        5700000,
        5799999,
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
    ),
    (
        '99999999-9999-9999-9999-999999999986',
        'CARRIER2-STANDARD-BRL',
        'carrier_2',
        'standard',
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
    ),
    (
        -- Covers the heavy product (~10.5kg) — the previous single band only went up to 2kg.
        '99999999-9999-9999-9999-999999999987',
        '99999999-9999-9999-9999-999999999986',
        '33333333-3333-3333-3333-333333333333',
        'SP-057',
        0,
        15,
        19.90,
        2,
        1,
        4.50,
        0,
        0,
        0,
        30,
        0,
        15.00
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

-- ============================================================================
-- Representative example journey #2: heavy product (>= 10kg), second carrier,
-- second destination. Exercises the new routing lane, carrier_2/standard rate
-- band and postal zone added above. Tables below are the EF-compat set actually
-- read by CheckoutService/OrderService/ShipmentService/TrackingService/
-- NotificationService (verified against their repositories/DbContexts).
-- ============================================================================

INSERT INTO checkout.checkouts (
    id, buyer_id, seller_id, status, shipping_promise_id, shipping_mode, carrier,
    estimated_delivery_date, items_total, shipping_cost, total_amount, idempotency_key,
    confirmation_idempotency_key, payment_intent_id, created_at, updated_at, expires_at, confirmed_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121201',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'Confirmed',
        'promise_heavy_001',
        'standard',
        'carrier_2',
        '2026-07-04',
        249.90,
        54.36,
        304.26,
        'idem-heavy-checkout-001',
        'idem-heavy-confirm-001',
        'pi_heavy_001',
        '2026-07-01 09:00:00-03',
        '2026-07-01 09:05:00-03',
        '2026-07-01 09:15:00-03',
        '2026-07-01 09:05:00-03'
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO checkout.checkout_items (
    id, checkout_id, sku_id, quantity, unit_price
) VALUES
    (
        '12121212-1212-1212-1212-121212121202',
        '12121212-1212-1212-1212-121212121201',
        '11111111-1111-1111-1111-111111111126',
        1,
        249.90
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO shipping_promise.shipping_promises (
    promise_id, checkout_id, buyer_id, seller_id, mode, carrier_code, route_id,
    service_level_code, origin_node_id, estimated_delivery_date, cost, currency,
    source, status, request_payload, result_payload, correlation_id, created_at
) VALUES
    (
        'promise_heavy_001',
        '12121212-1212-1212-1212-121212121201',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'standard',
        'carrier_2',
        'route_sp_standard_05700000',
        'standard',
        '33333333-3333-3333-3333-333333333333',
        '2026-07-04',
        54.36,
        'BRL',
        'calculated',
        'calculated',
        '{"checkoutId":"12121212-1212-1212-1212-121212121201"}',
        '{"available":true,"mode":"standard","carrier":"carrier_2"}',
        'cccccccc-cccc-cccc-cccc-cccccccccc02',
        '2026-07-01 09:00:20-03'
    )
ON CONFLICT (promise_id) DO NOTHING;

-- CheckoutService reads id/event_id/correlation_id/carrier/created_at (lowercase, unquoted)
-- from this table (see ShippingPromiseProjectionRepository.cs) — checkout_id, promise_id,
-- mode, estimated_delivery_date and cost already exist as canonical lowercase columns.
INSERT INTO checkout.shipping_promise_projections (
    id, event_id, correlation_id, checkout_id, promise_id, mode, carrier,
    estimated_delivery_date, cost, created_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121203',
        '12121212-1212-1212-1212-121212121204',
        'cccccccc-cccc-cccc-cccc-cccccccccc02',
        '12121212-1212-1212-1212-121212121201',
        'promise_heavy_001',
        'standard',
        'carrier_2',
        '2026-07-04',
        54.36,
        '2026-07-01 09:00:25-03'
    )
ON CONFLICT (id) DO NOTHING;

-- OrderService's OrderDbContext targets bare table names (no schema-qualified FKs to
-- CheckoutService); checkout_id below is CheckoutService's own compat `id`.
INSERT INTO order_domain.orders (
    order_id, id, checkout_id, buyer_id, seller_id, shipping_promise_id, status,
    currency, items_total, shipping_price, total_amount, destination,
    correlation_id, created_at, updated_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121205',
        '12121212-1212-1212-1212-121212121205',
        '12121212-1212-1212-1212-121212121201',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'promise_heavy_001',
        'confirmed',
        'BRL',
        249.90,
        54.36,
        304.26,
        '{"street":"Rua Augusta","number":"500","city":"Sao Paulo","state":"SP","zipCode":"05700-000","country":"BR"}',
        'cccccccc-cccc-cccc-cccc-cccccccccc02',
        '2026-07-01 09:05:30-03',
        '2026-07-01 09:10:00-03'
    )
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO order_domain.order_items (
    order_item_id, id, order_id, sku_id, title, quantity, unit_price
) VALUES
    (
        '12121212-1212-1212-1212-121212121206',
        '12121212-1212-1212-1212-121212121206',
        '12121212-1212-1212-1212-121212121205',
        '11111111-1111-1111-1111-111111111126',
        'Kit Halteres 10kg Demo',
        1,
        249.90
    )
ON CONFLICT (order_item_id) DO NOTHING;

INSERT INTO order_domain.order_saga_states (
    order_id, current_step, status, compensation_payload, version, updated_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121205',
        'completed',
        'confirmed',
        '{}',
        1,
        '2026-07-01 09:10:00-03'
    )
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO payment.payment_authorizations (
    payment_authorization_id, order_id, buyer_id, amount, currency, payment_method,
    provider, provider_authorization_id, status, authorized_at, created_at, updated_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121207',
        '12121212-1212-1212-1212-121212121205',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        304.26,
        'BRL',
        'credit_card',
        'mercadopago',
        'mp_auth_heavy_001',
        'captured',
        '2026-07-01 09:07:00-03',
        '2026-07-01 09:06:30-03',
        '2026-07-01 09:10:00-03'
    )
ON CONFLICT (payment_authorization_id) DO NOTHING;

-- ShipmentService's ShipmentDbContext uses shipment_packages/shipment_package_items, not
-- shipment_volumes/shipment_volume_items.
INSERT INTO shipment.shipments (
    shipment_id, id, order_id, buyer_id, seller_id, carrier_code, service_level_code,
    shipping_promise_id, route_id, origin_node_id, promised_delivery_date,
    external_shipment_id, tracking_code, label_object_key, status,
    recipient_name, street, number, district, city, state, destination_postal_code, country, phone,
    created_at, updated_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121208',
        '12121212-1212-1212-1212-121212121208',
        '12121212-1212-1212-1212-121212121205',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222',
        'carrier_2',
        'standard',
        'promise_heavy_001',
        'route_sp_standard_05700000',
        '33333333-3333-3333-3333-333333333333',
        '2026-07-04',
        'ext_heavy_001',
        'BR987654321',
        'labels/shp_heavy_001.pdf',
        'in_transit',
        'Comprador Demo',
        'Rua Augusta',
        '500',
        'Centro',
        'Sao Paulo',
        'SP',
        '05700-000',
        'BR',
        '+5511999990000',
        '2026-07-01 09:11:00-03',
        '2026-07-01 12:00:00-03'
    )
ON CONFLICT (shipment_id) DO NOTHING;

INSERT INTO shipment.shipment_packages (
    id, shipment_id, sequence, weight_kg, height_cm, width_cm, length_cm
) VALUES
    (
        '12121212-1212-1212-1212-121212121209',
        '12121212-1212-1212-1212-121212121208',
        1,
        10.500,
        20.00,
        20.00,
        40.00
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO shipment.shipment_package_items (
    id, shipment_package_id, sku_id, quantity
) VALUES
    (
        '12121212-1212-1212-1212-121212121210',
        '12121212-1212-1212-1212-121212121209',
        '11111111-1111-1111-1111-111111111126',
        1
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO tracking.tracking_events (
    id, shipment_id, order_id, buyer_id, provider_event_id, tracking_code, carrier_code,
    carrier_sequence, status, description, occurred_at, received_at, estimated_delivery_date,
    facility_code, location_city, location_state, location_country
) VALUES
    (
        '12121212-1212-1212-1212-121212121211',
        '12121212-1212-1212-1212-121212121208',
        '12121212-1212-1212-1212-121212121205',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'carrier2_evt_001',
        'BR987654321',
        'carrier_2',
        1,
        'InTransit',
        'Pacote em transito',
        '2026-07-01 12:00:00-03',
        '2026-07-01 12:00:05-03',
        '2026-07-04',
        'LM-SP-057',
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
        '12121212-1212-1212-1212-121212121208',
        '12121212-1212-1212-1212-121212121205',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'BR987654321',
        'carrier_2',
        'InTransit',
        '12121212-1212-1212-1212-121212121211',
        1,
        '2026-07-01 12:00:00-03',
        '2026-07-01 12:00:05-03',
        '2026-07-04',
        1,
        'LM-SP-057',
        'Sao Paulo',
        'SP',
        'BR'
    )
ON CONFLICT (shipment_id) DO NOTHING;

-- NotificationService's NotificationDbContext uses notifications/notification_deliveries,
-- not notification_plans/notification_logs.
INSERT INTO notification.notifications (
    id, source_event_id, recipient_id, type, priority, status, locale, created_at, updated_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121212',
        '12121212-1212-1212-1212-121212121208',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'shipment.created',
        'normal',
        'sent',
        'pt-BR',
        '2026-07-01 09:11:10-03',
        '2026-07-01 09:11:10-03'
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO notification.notification_deliveries (
    id, notification_id, channel, status, destination, template_id, template_version,
    subject, body, provider_message_id, attempts, created_at, updated_at, accepted_at, delivered_at
) VALUES
    (
        '12121212-1212-1212-1212-121212121213',
        '12121212-1212-1212-1212-121212121212',
        'email',
        'delivered',
        'buyer-demo@example.com',
        '12121212-1212-1212-1212-121212129999',
        1,
        'Sua entrega foi criada',
        'Seu pedido do Kit Halteres 10kg foi despachado, chegada estimada 2026-07-04.',
        'msg_heavy_email_001',
        1,
        '2026-07-01 09:11:10-03',
        '2026-07-01 09:11:12-03',
        '2026-07-01 09:11:11-03',
        '2026-07-01 09:11:12-03'
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO audit.audit_entries (
    entry_id, event_id, event_type, schema_version, correlation_id, occurred_at,
    producer, topic, partition, offset_value, payload, metadata
) VALUES
    (
        'ffffffff-ffff-ffff-ffff-fffffffffff4',
        'ffffffff-ffff-ffff-ffff-fffffffff004',
        'checkout.confirmed',
        '1.0',
        'cccccccc-cccc-cccc-cccc-cccccccccc02',
        '2026-07-01 09:05:00-03',
        'checkout-service',
        'checkout.confirmed',
        0,
        4,
        '{"checkoutId":"12121212-1212-1212-1212-121212121201","buyerId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","sellerId":"22222222-2222-2222-2222-222222222222","shippingPromiseId":"promise_heavy_001","totalAmount":304.26,"currency":"BRL"}',
        '{"seed":true,"example":"heavy_product"}'
    ),
    (
        'ffffffff-ffff-ffff-ffff-fffffffffff5',
        'ffffffff-ffff-ffff-ffff-fffffffff005',
        'shipment.status.updated',
        '1.0',
        'cccccccc-cccc-cccc-cccc-cccccccccc02',
        '2026-07-01 12:00:00-03',
        'tracking-service',
        'shipment.status.updated',
        0,
        5,
        '{"shipmentId":"12121212-1212-1212-1212-121212121208","orderId":"12121212-1212-1212-1212-121212121205","buyerId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","trackingCode":"BR987654321","carrierCode":"carrier_2","previousStatus":"created","currentStatus":"in_transit"}',
        '{"seed":true,"example":"heavy_product"}'
    )
ON CONFLICT (event_id) DO NOTHING;

COMMIT;


