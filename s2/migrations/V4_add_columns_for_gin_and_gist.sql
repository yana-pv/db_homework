-- 1. JSONB колонка в car
ALTER TABLE car ADD COLUMN tech_specs jsonb;

UPDATE car 
SET tech_specs = 
    CASE (random()*4)::int
        WHEN 0 THEN '{"engine": {"type": "petrol", "volume": 2.0}, "transmission": "manual"}'
        WHEN 1 THEN '{"engine": {"type": "diesel", "volume": 3.0}, "transmission": "auto"}'
        WHEN 2 THEN '{"engine": {"type": "hybrid", "volume": 1.8}, "transmission": "CVT"}'
        WHEN 3 THEN '{"engine": {"type": "petrol", "volume": 1.6}, "options": ["climate"]}'
        ELSE '{"engine": {"type": "electric", "power": 200}, "transmission": "auto"}'
    END::jsonb
WHERE random() < 0.3;  -- только 30% машин

-- 2. to_tsvector для полнотекстового поиска
ALTER TABLE client_order ADD COLUMN search_vector tsvector;

UPDATE client_order 
SET search_vector = 
    to_tsvector('russian', COALESCE(notes, ''));

-- 3. Диапазоны для GiST
ALTER TABLE client_order ADD COLUMN completion_period daterange;

UPDATE client_order 
SET completion_period = 
    daterange(created_date::date, 
              COALESCE(completion_date::date, CURRENT_DATE), 
              '[]');

ANALYZE car;
ANALYZE client_order;