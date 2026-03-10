-- GIN
CREATE INDEX idx_car_specs_gin ON car USING GIN(tech_specs);
CREATE INDEX idx_order_search_gin ON client_order USING GIN(search_vector);

-- 1. to_tsquery с AND
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, notes 
FROM client_order
WHERE search_vector @@ to_tsquery('russian', 'срочный & ремонт');

-- 2. to_tsquery с OR
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, notes 
FROM client_order
WHERE search_vector @@ to_tsquery('russian', 'тормоза | сцепление');

-- 3. to_tsquery с NOT
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, notes 
FROM client_order
WHERE search_vector @@ to_tsquery('russian', 'замена & !гарантия');

-- 4. to_tsquery с фразой
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, notes 
FROM client_order
WHERE search_vector @@ to_tsquery('russian', 'проблема <-> двигатель');

-- 5. JSONB поиск
EXPLAIN (ANALYZE, BUFFERS)
SELECT vin, tech_specs 
FROM car
WHERE tech_specs @> '{"engine": {"type": "electric"}}';

DROP INDEX idx_car_specs_gin;
DROP INDEX idx_order_search_gin;


-- GIST
CREATE INDEX idx_order_search_gist ON client_order USING gist(search_vector);
CREATE INDEX idx_order_completion_gist ON client_order USING gist(completion_period);

-- 1. Диапазон - пересечение
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, created_date 
FROM client_order
WHERE completion_period && daterange('2025-05-01', '2025-06-01');

-- 2. Диапазон - содержание
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, created_date 
FROM client_order
WHERE completion_period @> daterange('2025-03-15', '2025-03-20');

-- 3. Диапазон - слева
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, created_date 
FROM client_order
WHERE completion_period << daterange('2025-01-01', '2025-02-01');

-- 4. Диапазон - смежные 
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, created_date, completion_date
FROM client_order
WHERE completion_period -|- daterange('2025-06-01', '2025-06-10');

-- 5. Полнотекстовый поиск на GiST 
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, notes 
FROM client_order
WHERE search_vector @@ to_tsquery('russian', 'срочный & ремонт');

DROP INDEX idx_order_search_gist;
DROP INDEX idx_order_completion_gist;


-- JOIN 
-- 1. 
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.full_name, o.created_date
FROM client c
JOIN client_order o ON c.id = o.id_client
WHERE c.id < 100;

-- 2.
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.full_name, COUNT(o.id)
FROM client c
JOIN client_order o ON c.id = o.id_client
GROUP BY c.full_name;

-- 3.
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.full_name, o.created_date
FROM client c
JOIN client_order o ON c.id = o.id_client
ORDER BY c.id, o.id_client;

-- 4.
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.full_name, cm.brand_name, o.created_date
FROM client c
JOIN client_order o ON c.id = o.id_client
JOIN car ca ON o.id_car = ca.id
JOIN car_model cm ON ca.model_id = cm.id
WHERE o.status = 'выполнен';

-- 5.
EXPLAIN (ANALYZE, BUFFERS)
SELECT cm.brand_name, cm.model_name, c.vin, c.tech_specs
FROM car c
JOIN car_model cm ON c.model_id = cm.id
WHERE c.tech_specs @> '{"engine": {"type": "electric"}}' AND c.year > 2020
LIMIT 50;

