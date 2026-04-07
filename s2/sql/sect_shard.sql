-- 1.1 Секционирование по RANGE (по датам создания заказов)
DROP TABLE IF EXISTS client_order_range CASCADE;

CREATE TABLE client_order_range (
  id integer NOT NULL,
  id_client integer NOT NULL,
  id_car integer NOT NULL,
  id_location integer NOT NULL,
  employee_id integer NOT NULL,
  created_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_amount integer NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  status order_status DEFAULT 'создан' NOT NULL,
  completion_date timestamp,
  notes text,
  priority order_priority DEFAULT 'обычный' NOT NULL,
  CONSTRAINT client_order_range_pkey PRIMARY KEY (id, created_date)
) PARTITION BY RANGE (created_date);

-- Создаем секции по месяцам 
CREATE TABLE client_order_2026_01 PARTITION OF client_order_range
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE client_order_2026_02 PARTITION OF client_order_range
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE client_order_2026_03 PARTITION OF client_order_range
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE client_order_future PARTITION OF client_order_range
  FOR VALUES FROM ('2026-04-01') TO (MAXVALUE);

-- Копируем данные из существующей таблицы
INSERT INTO client_order_range 
SELECT id, id_client, id_car, id_location, employee_id, 
       created_date, total_amount, status, completion_date, notes, priority
FROM client_order 
WHERE created_date >= '2026-01-01';

-- Создаем индексы на секционированной таблице 
CREATE INDEX idx_client_order_range_created_date ON client_order_range (created_date);
CREATE INDEX idx_client_order_range_client ON client_order_range (id_client);

-- 1.2 Секционирование по LIST (по статусу заказа)
DROP TABLE IF EXISTS client_order_list CASCADE;

CREATE TABLE client_order_list (
  id integer NOT NULL,
  id_client integer NOT NULL,
  id_car integer NOT NULL,
  id_location integer NOT NULL,
  employee_id integer NOT NULL,
  created_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_amount integer NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  status order_status DEFAULT 'создан' NOT NULL,
  completion_date timestamp,
  notes text,
  priority order_priority DEFAULT 'обычный' NOT NULL,
  CONSTRAINT client_order_list_pkey PRIMARY KEY (id, status)
) PARTITION BY LIST (status);

CREATE TABLE client_order_created PARTITION OF client_order_list
  FOR VALUES IN ('создан');

CREATE TABLE client_order_inwork PARTITION OF client_order_list
  FOR VALUES IN ('в работе');

CREATE TABLE client_order_completed PARTITION OF client_order_list
  FOR VALUES IN ('выполнен');

CREATE TABLE client_order_cancelled PARTITION OF client_order_list
  FOR VALUES IN ('отменен');

-- Копируем данные
INSERT INTO client_order_list 
SELECT id, id_client, id_car, id_location, employee_id, 
       created_date, total_amount, status, completion_date, notes, priority
FROM client_order;

-- Создаем индексы
CREATE INDEX idx_client_order_list_status ON client_order_list (status);
CREATE INDEX idx_client_order_list_client ON client_order_list (id_client);


-- 1.3 Секционирование по HASH (по id клиента)
DROP TABLE IF EXISTS client_order_hash CASCADE;

CREATE TABLE client_order_hash (
  id integer NOT NULL,
  id_client integer NOT NULL,
  id_car integer NOT NULL,
  id_location integer NOT NULL,
  employee_id integer NOT NULL,
  created_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_amount integer NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  status order_status DEFAULT 'создан' NOT NULL,
  completion_date timestamp,
  notes text,
  priority order_priority DEFAULT 'обычный' NOT NULL,
  CONSTRAINT client_order_hash_pkey PRIMARY KEY (id, id_client)
) PARTITION BY HASH (id_client);

-- Создаем 4 хеш-секции
CREATE TABLE client_order_hash_0 PARTITION OF client_order_hash
  FOR VALUES WITH (MODULUS 4, REMAINDER 0);
  
CREATE TABLE client_order_hash_1 PARTITION OF client_order_hash
  FOR VALUES WITH (MODULUS 4, REMAINDER 1);
  
CREATE TABLE client_order_hash_2 PARTITION OF client_order_hash
  FOR VALUES WITH (MODULUS 4, REMAINDER 2);
  
CREATE TABLE client_order_hash_3 PARTITION OF client_order_hash
  FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Копируем данные
INSERT INTO client_order_hash 
SELECT id, id_client, id_car, id_location, employee_id, 
       created_date, total_amount, status, completion_date, notes, priority
FROM client_order;

-- Создаем индексы
CREATE INDEX idx_client_order_hash_client ON client_order_hash (id_client);
CREATE INDEX idx_client_order_hash_created ON client_order_hash (created_date);


EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM client_order_range 
WHERE created_date BETWEEN '2026-01-15' AND '2026-02-15';

EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM client_order_list 
WHERE status = 'выполнен';

EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM client_order_hash 
WHERE id_client = 12345;

drop table client_order_2026_01;
drop table client_order_2026_02;
drop table client_order_2026_03;
drop table client_order_future;

-- 2. Создаем тестовую секционированную таблицу
CREATE TABLE test_partition (
  id serial,
  created_date date,
  data text
) PARTITION BY RANGE (created_date);

CREATE TABLE test_partition_2026_01 PARTITION OF test_partition
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

INSERT INTO test_partition (created_date, data) 
VALUES ('2026-01-15', 'test data');

-- 3. Создаем секционированную таблицу для теста
DROP TABLE IF EXISTS test_partition_root CASCADE;

CREATE TABLE test_partition_root (
  id SERIAL,
  created_date DATE NOT NULL,
  data TEXT,
  region VARCHAR(50),
  PRIMARY KEY (id, created_date)
) PARTITION BY RANGE (created_date);

-- Создаем секции по месяцам
CREATE TABLE test_partition_2026_01 PARTITION OF test_partition_root
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE test_partition_2026_02 PARTITION OF test_partition_root
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE test_partition_2026_03 PARTITION OF test_partition_root
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE test_partition_default PARTITION OF test_partition_root DEFAULT;

-- Добавляем немного данных
INSERT INTO test_partition_root (created_date, data, region) VALUES
  ('2026-01-15', 'Data for January', 'Moscow'),
  ('2026-01-20', 'Another January data', 'SPB'),
  ('2026-02-10', 'February data', 'Kazan'),
  ('2026-02-25', 'Another February', 'Moscow'),
  ('2026-03-05', 'March data', 'Novosibirsk');

-- Проверяем, что данные распределились по секциям
SELECT '2026_01' as partition, COUNT(*) FROM test_partition_2026_01
UNION ALL
SELECT '2026_02', COUNT(*) FROM test_partition_2026_02
UNION ALL
SELECT '2026_03', COUNT(*) FROM test_partition_2026_03
UNION ALL
SELECT 'DEFAULT', COUNT(*) FROM test_partition_default;

-- publish_via_partition_root = false
-- Создаем публикацию с явным указанием false
DROP PUBLICATION IF EXISTS test_partition_pub_off;

CREATE PUBLICATION test_partition_pub_off 
FOR TABLE test_partition_root 
WITH (publish_via_partition_root = false);

-- Проверяем публикацию
SELECT 
  p.pubname,
  pt.schemaname,
  pt.tablename
FROM pg_publication p
JOIN pg_publication_tables pt ON p.pubname = pt.pubname;


-- publish_via_partition_root = true
-- Создаем публикацию с параметром true
DROP PUBLICATION IF EXISTS test_partition_pub_on;

CREATE PUBLICATION test_partition_pub_on 
FOR TABLE test_partition_root 
WITH (publish_via_partition_root = true);

-- Смотрим список публикаций
SELECT pubname, puballtables FROM pg_publication;


-- 4. Шардирование 
-- Создаем схемы для изоляции шардов
DROP SCHEMA IF EXISTS shard1 CASCADE;
DROP SCHEMA IF EXISTS shard2 CASCADE;
CREATE SCHEMA shard1;
CREATE SCHEMA shard2;

-- Создаем таблицу шарда 1 (данные с ключами 0, 1)
CREATE TABLE shard1.orders (
  id SERIAL PRIMARY KEY,
  client_id INTEGER NOT NULL,
  order_data TEXT,
  shard_key INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  total_amount INTEGER DEFAULT 0
);

-- Создаем таблицу шарда 2 (данные с ключами 2, 3)
CREATE TABLE shard2.orders (
  id SERIAL PRIMARY KEY,
  client_id INTEGER NOT NULL,
  order_data TEXT,
  shard_key INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  total_amount INTEGER DEFAULT 0
);

-- Заполняем шард 1 (клиенты с id % 2 = 0 или 1)
INSERT INTO shard1.orders (client_id, order_data, shard_key, total_amount)
SELECT 
  id,
  'Order from client ' || id,
  id % 2,
  (random() * 50000)::int
FROM client 
WHERE id % 2 IN (0, 1)
LIMIT 10000;

-- Заполняем шард 2 (клиенты с id % 4 = 2 или 3)
INSERT INTO shard2.orders (client_id, order_data, shard_key, total_amount)
SELECT 
  id,
  'Order from client ' || id,
  id % 4,
  (random() * 50000)::int
FROM client 
WHERE id % 4 IN (2, 3)
LIMIT 10000;

-- Проверяем заполнение
SELECT 'Shard 1' as shard, COUNT(*) as rows, MIN(client_id) as min_client, MAX(client_id) as max_client FROM shard1.orders
UNION ALL
SELECT 'Shard 2', COUNT(*), MIN(client_id), MAX(client_id) FROM shard2.orders;

-- Создаем расширение 
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Создаем серверы для каждого шарда
-- Сервер для шарда 1
DROP SERVER IF EXISTS shard1_server CASCADE;
CREATE SERVER shard1_server 
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'autoservice-postgres', port '5432', dbname 'autoservice');

-- Сервер для шарда 2
DROP SERVER IF EXISTS shard2_server CASCADE;
CREATE SERVER shard2_server 
FOREIGN DATA WRAPPER postgres_fdw 
OPTIONS (host 'autoservice-postgres', port '5432', dbname 'autoservice');

-- Создаем пользовательские маппинги
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER 
SERVER shard1_server 
OPTIONS (user 'admin', password 'admin');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER 
SERVER shard2_server 
OPTIONS (user 'admin', password 'admin');

-- Создаем внешние таблицы (обертки над реальными таблицами)
DROP FOREIGN TABLE IF EXISTS fdw_shard1_orders CASCADE;
DROP FOREIGN TABLE IF EXISTS fdw_shard2_orders CASCADE;

-- Внешняя таблица для шарда 1
CREATE FOREIGN TABLE fdw_shard1_orders (
  id INTEGER,
  client_id INTEGER,
  order_data TEXT,
  shard_key INTEGER,
  created_at TIMESTAMP,
  total_amount INTEGER
) SERVER shard1_server OPTIONS (schema_name 'shard1', table_name 'orders');

-- Внешняя таблица для шарда 2
CREATE FOREIGN TABLE fdw_shard2_orders (
  id INTEGER,
  client_id INTEGER,
  order_data TEXT,
  shard_key INTEGER,
  created_at TIMESTAMP,
  total_amount INTEGER
) SERVER shard2_server OPTIONS (schema_name 'shard2', table_name 'orders');

-- Создаем секционированную таблицу-роутер
DROP TABLE IF EXISTS shard_router CASCADE;

CREATE TABLE shard_router (
  id INTEGER,
  client_id INTEGER,
  order_data TEXT,
  shard_key INTEGER,
  created_at TIMESTAMP,
  total_amount INTEGER
) PARTITION BY LIST (shard_key);

-- Присоединяем внешние таблицы как секции
-- Шард 1 обрабатывает ключи 0 и 1
ALTER TABLE shard_router ATTACH PARTITION fdw_shard1_orders 
FOR VALUES IN (0, 1);

-- Шард 2 обрабатывает ключи 2 и 3
ALTER TABLE shard_router ATTACH PARTITION fdw_shard2_orders 
FOR VALUES IN (2, 3);

-- Проверяем, что роутер видит все данные
SELECT COUNT(*) as total_rows FROM shard_router;
SELECT shard_key, COUNT(*) as rows FROM shard_router GROUP BY shard_key ORDER BY shard_key;

-- Запрос на все данные 
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(total_amount) FROM shard_router;

-- Запрос на конкретный шард 
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(total_amount) FROM shard_router WHERE shard_key = 0;

-- Запрос на несколько шардов (2 шарда)
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(total_amount) FROM shard_router WHERE shard_key IN (1, 2);

-- Запрос с условием не по ключу (сканируются все шарды)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM shard_router WHERE client_id = 100;