-- 1. Тстовые клиенты
INSERT INTO client (full_name, phone_number, email, driver_license) 
VALUES
    ('Иванов Петр', '+79991112233', 'ivanov@test.com', 'TEST111'),
    ('Петрова Анна', '+79992223344', 'petrova@test.com', 'TEST222'),
    ('Сидоров Михаил', '+79993334455', 'sidorov@test.com', 'TEST333')
ON CONFLICT (driver_license) DO NOTHING;

-- 2. Тестовые услуги
INSERT INTO service (name, base_price, lead_time) 
VALUES
    ('Замена масла', 2500, 60),
    ('Диагностика', 3000, 120),
    ('Шиномонтаж', 2000, 45)
ON CONFLICT (name) DO NOTHING;

-- 3. Тестовые поставщики (без ON CONFLICT - для демонстрации проблемы)
INSERT INTO supplier (company_name, phone_number, email, bank_account) 
VALUES ('ООО Автозапчасти', '+74951112233', 'info@auto.ru', '12345678901');

-- 4. Проверка
SELECT 'client' as table_name, COUNT(*) FROM client WHERE driver_license LIKE 'TEST%'
UNION ALL
SELECT 'service', COUNT(*) FROM service WHERE name LIKE 'Замена%' OR name LIKE 'Диагностика%';

-- Запоминаем количество ДО
CREATE TEMP TABLE before_counts AS
SELECT 'client' as tbl, COUNT(*) as cnt FROM client WHERE driver_license LIKE 'TEST%'
UNION ALL
SELECT 'service', COUNT(*) FROM service WHERE name LIKE 'Замена%' OR name LIKE 'Диагностика%'
UNION ALL
SELECT 'supplier', COUNT(*) FROM supplier WHERE company_name = 'ООО Автозапчасти';

-- Запускаем seed повторно
INSERT INTO client (full_name, phone_number, email, driver_license) 
VALUES
    ('Иванов Петр', '+79991112233', 'ivanov@test.com', 'TEST111'),
    ('Петрова Анна', '+79992223344', 'petrova@test.com', 'TEST222'),
    ('Сидоров Михаил', '+79993334455', 'sidorov@test.com', 'TEST333')
ON CONFLICT (driver_license) DO NOTHING;

INSERT INTO service (name, base_price, lead_time) 
VALUES
    ('Замена масла', 2500, 60),
    ('Диагностика', 3000, 120),
    ('Шиномонтаж', 2000, 45)
ON CONFLICT (name) DO NOTHING;

INSERT INTO supplier (company_name, phone_number, email, bank_account) 
VALUES ('ООО Автозапчасти', '+74951112233', 'info@auto.ru', '12345678901');

-- Сравниваем ПОСЛЕ
WITH after_counts AS (
    SELECT 'client' as tbl, COUNT(*) as cnt FROM client WHERE driver_license LIKE 'TEST%'
    UNION ALL
    SELECT 'service', COUNT(*) FROM service WHERE name LIKE 'Замена%' OR name LIKE 'Диагностика%'
    UNION ALL
    SELECT 'supplier', COUNT(*) FROM supplier WHERE company_name = 'ООО Автозапчасти'
)
SELECT 
    b.tbl,
    b.cnt as before,
    a.cnt as after,
    a.cnt - b.cnt as diff,
    CASE 
	    WHEN a.cnt - b.cnt = 0 THEN 'Идемпотентно' ELSE 'Есть дубликаты' 
	END as status
FROM before_counts b
JOIN after_counts a ON b.tbl = a.tbl;

DROP TABLE before_counts;