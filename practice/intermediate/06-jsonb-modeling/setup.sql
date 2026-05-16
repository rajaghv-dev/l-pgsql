-- Practice 06: JSONB Modeling
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql

DROP TABLE IF EXISTS jsonb_field_registry CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

CREATE TABLE categories (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    category_id INT REFERENCES categories(id),
    price       NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    attributes  JSONB,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- GIN index on attributes
CREATE INDEX ON products USING gin(attributes);

-- JSONB field data dictionary
CREATE TABLE jsonb_field_registry (
    id          SERIAL PRIMARY KEY,
    table_name  TEXT NOT NULL,
    field_path  TEXT NOT NULL,  -- e.g. 'attributes.color'
    field_type  TEXT NOT NULL,  -- e.g. 'text', 'numeric', 'boolean'
    description TEXT,
    UNIQUE(table_name, field_path)
);

-- ============================================================
-- Seed
-- ============================================================

INSERT INTO categories (name) VALUES
    ('electronics'), ('footwear'), ('furniture'), ('food');

INSERT INTO products (name, category_id, price, attributes) VALUES
    ('Laptop X1',      1, 999.00,  '{"brand":"Nexus","ram_gb":16,"storage_gb":512,"color":"silver","weight_kg":1.4}'),
    ('Tablet Pro',     1, 499.00,  '{"brand":"Nexus","ram_gb":8,"storage_gb":128,"color":"black","has_stylus":true}'),
    ('Running Shoe A', 2, 79.99,   '{"brand":"StridePro","size":10,"color":"blue","waterproof":true}'),
    ('Running Shoe B', 2, 89.99,   '{"brand":"StridePro","size":9,"color":"red","waterproof":false}'),
    ('Office Chair',   3, 299.00,  '{"brand":"ErgoSit","adjustable":true,"color":"black","max_weight_kg":120}'),
    ('Standing Desk',  3, 450.00,  '{"brand":"DeskPro","width_cm":160,"height_adjustable":true}'),
    ('Dark Chocolate', 4, 4.99,    '{"brand":"CocoFarm","weight_g":100,"cocoa_pct":72,"vegan":true}'),
    ('Oat Milk',       4, 3.49,    '{"brand":"OatField","volume_ml":1000,"calories_per_100ml":47,"vegan":true}');

INSERT INTO jsonb_field_registry (table_name, field_path, field_type, description) VALUES
    ('products', 'attributes.brand',       'text',    'Manufacturer or brand name'),
    ('products', 'attributes.color',       'text',    'Primary color'),
    ('products', 'attributes.vegan',       'boolean', 'Whether the product is vegan'),
    ('products', 'attributes.ram_gb',      'numeric', 'RAM in gigabytes (electronics)'),
    ('products', 'attributes.storage_gb',  'numeric', 'Storage in gigabytes (electronics)'),
    ('products', 'attributes.waterproof',  'boolean', 'Whether the product is waterproof (footwear)');

SELECT 'products' AS tbl, COUNT(*) FROM products
UNION ALL
SELECT 'categories', COUNT(*) FROM categories
UNION ALL
SELECT 'jsonb_field_registry', COUNT(*) FROM jsonb_field_registry;
