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

-- 3.1
EXPLAIN 
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

EXPLAIN ANALYZE
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

-- 3.2
CREATE INDEX idx_car_vin_btree ON car(vin);

EXPLAIN 
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

EXPLAIN ANALYZE
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

DROP INDEX idx_car_vin_btree;

-- 3.3
CREATE INDEX idx_car_vin_hash ON car USING hash(vin);

EXPLAIN 
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

EXPLAIN ANALYZE
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM car WHERE vin = '1HGBH41JXMN109186';

DROP INDEX idx_car_vin_hash;

-- 4.1
EXPLAIN 
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

EXPLAIN ANALYZE
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

EXPLAIN (ANALYZE, BUFFERS)
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

-- 4.2
CREATE INDEX idx_employee_phone_btree ON employee(phone_number);

EXPLAIN 
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

EXPLAIN ANALYZE
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

EXPLAIN (ANALYZE, BUFFERS)
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

DROP INDEX idx_employee_phone_btree;

-- 4.3
CREATE INDEX idx_employee_phone_hash ON employee USING hash(phone_number);

EXPLAIN 
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

EXPLAIN ANALYZE
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

EXPLAIN (ANALYZE, BUFFERS)
UPDATE employee SET status = 'отпуск' WHERE phone_number = '+79991234567';

DROP INDEX idx_employee_phone_hash;

-- 5.1
EXPLAIN 
DELETE FROM client WHERE driver_license = 'AB12345678';

EXPLAIN ANALYZE
DELETE FROM client WHERE driver_license = 'AB12345678';

EXPLAIN (ANALYZE, BUFFERS)
DELETE FROM client WHERE driver_license = 'AB12345678';

-- 5.2
CREATE INDEX idx_client_dl_btree ON client(driver_license);

EXPLAIN 
DELETE FROM client WHERE driver_license = 'AB12345678';

EXPLAIN ANALYZE
DELETE FROM client WHERE driver_license = 'AB12345678';

EXPLAIN (ANALYZE, BUFFERS)
DELETE FROM client WHERE driver_license = 'AB12345678';

DROP INDEX idx_client_dl_btree;


-- 5.3
CREATE INDEX idx_client_dl_hash ON client USING hash(driver_license);

EXPLAIN 
DELETE FROM client WHERE driver_license = 'AB12345678';

EXPLAIN ANALYZE
DELETE FROM client WHERE driver_license = 'AB12345678';

EXPLAIN (ANALYZE, BUFFERS)
DELETE FROM client WHERE driver_license = 'AB12345678';

DROP INDEX idx_client_dl_hash;