DISCARD ALL;

VACUUM ANALYZE;

-- 1.1
EXPLAIN
SELECT * FROM client WHERE phone_number = '+79991234567';

EXPLAIN ANALYZE
SELECT * FROM client WHERE phone_number = '+79991234567';

EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM client WHERE phone_number = '+79991234567';

-- 1.2
CREATE INDEX idx_client_phone_btree ON client(phone_number); 

EXPLAIN
SELECT * FROM client WHERE phone_number = '+79991234567';

EXPLAIN ANALYZE
SELECT * FROM client WHERE phone_number = '+79991234567';

EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM client WHERE phone_number = '+79991234567';

DROP INDEX idx_client_phone_btree;

-- 1.3 
CREATE INDEX idx_client_phone_hash ON client USING hash(phone_number);

EXPLAIN
SELECT * FROM client WHERE phone_number = '+79991234567';

EXPLAIN ANALYZE
SELECT * FROM client WHERE phone_number = '+79991234567';

EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM client WHERE phone_number = '+79991234567';

DROP INDEX idx_client_phone_hash;

-- 2.1
EXPLAIN 
UPDATE client_order 
SET priority = 'высокий'
WHERE id IN (
    SELECT co.id 
    FROM client_order co
    JOIN car c ON co.id_car = c.id
    WHERE c.year < 2010
);

EXPLAIN ANALYZE
UPDATE client_order 
SET priority = 'высокий'
WHERE id IN (
    SELECT co.id 
    FROM client_order co
    JOIN car c ON co.id_car = c.id
    WHERE c.year < 2010
);

EXPLAIN (ANALYZE, BUFFERS)
UPDATE client_order 
SET priority = 'высокий'
WHERE id IN (
    SELECT co.id 
    FROM client_order co
    JOIN car c ON co.id_car = c.id
    WHERE c.year < 2010
);

-- 2.2
CREATE INDEX idx_car_year ON car(year);
CREATE INDEX idx_client_order_car ON client_order(id_car);

EXPLAIN 
UPDATE client_order 
SET priority = 'высокий'
WHERE id IN (
    SELECT co.id 
    FROM client_order co
    JOIN car c ON co.id_car = c.id
    WHERE c.year < 2010
);

EXPLAIN ANALYZE
UPDATE client_order 
SET priority = 'высокий'
WHERE id IN (
    SELECT co.id 
    FROM client_order co
    JOIN car c ON co.id_car = c.id
    WHERE c.year < 2010
);

EXPLAIN (ANALYZE, BUFFERS)
UPDATE client_order 
SET priority = 'высокий'
WHERE id IN (
    SELECT co.id 
    FROM client_order co
    JOIN car c ON co.id_car = c.id
    WHERE c.year < 2010
);

DROP INDEX idx_car_year;
DROP INDEX idx_client_order_car;
