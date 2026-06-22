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
    idempotency_key uuid,
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
