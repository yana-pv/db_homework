-- Посмотреть на изменение LSN и WAL после изменения данных
-- Сравнение LSN до и после INSERT
SELECT 'CURRENT WAL POSITION' as stage, 
       pg_current_wal_insert_lsn() as lsn_before;

INSERT INTO client (full_name, phone_number, email, driver_license)
VALUES (
    'Иванов Петр Сидорович',
    '+79991112233',
    'ivanov.ps@example.com',
    '77AB123456'
);

SELECT 'AFTER INSERT' as stage,
       pg_current_wal_insert_lsn() as lsn_after;

-- Сравнение WAL до и после commit
SELECT 
    'ДО COMMIT' as момент,
    pg_current_wal_insert_lsn() as lsn,
    pg_walfile_name(pg_current_wal_insert_lsn()) as wal_файл,
    pg_size_pretty((pg_current_wal_insert_lsn() - '0/0'::pg_lsn)::bigint) as всего_wal
    
BEGIN;
INSERT INTO client (full_name, phone_number, email, driver_license)
VALUES (
    'Простой тест',
    '+79991112233',
    'simple@test.com',
    'SIMPLE123'
);
COMMIT;

SELECT 
    'ПОСЛЕ COMMIT' as момент,
    pg_current_wal_insert_lsn() as lsn,
    pg_walfile_name(pg_current_wal_insert_lsn()) as wal_файл,
    pg_size_pretty((pg_current_wal_insert_lsn() - '0/0'::pg_lsn)::bigint) as всего_wal
    
-- Анализ WAL размера после массовой операции
CREATE TABLE wal_test (
    id serial PRIMARY KEY,
    data text,
    number_value integer,
    created_at timestamptz DEFAULT now()
);

-- Pазмер таблицы
SELECT 
    'Размер таблицы' as параметр,
    pg_size_pretty(pg_relation_size('wal_test')) as размер;

SELECT 
    'НАЧАЛО ЭКСПЕРИМЕНТА' as этап,
    pg_current_wal_insert_lsn() as lsn_start,
    pg_walfile_name(pg_current_wal_insert_lsn()) as wal_file,
    (SELECT count(*) FROM pg_ls_waldir()) as files_count,
    (SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir()) as total_wal_size;

-- Вставляем 10 000 записей 
DO $$
DECLARE
    records_count integer := 10000;
    start_lsn pg_lsn;
    end_lsn pg_lsn;
    start_time timestamptz;
    end_time timestamptz;
    bytes_generated bigint;
BEGIN
    -- Засекаем время и LSN
    start_time := clock_timestamp();
    start_lsn := pg_current_wal_insert_lsn();
    
    -- Массовая вставка
    INSERT INTO wal_test (data, number_value)
    SELECT 
        'Тестовые данные #' || gs,
        floor(random() * 1000000)
    FROM generate_series(1, records_count) gs;
    
    -- Фиксируем результаты
    end_lsn := pg_current_wal_insert_lsn();
    end_time := clock_timestamp();
    bytes_generated := end_lsn - start_lsn;
    
    -- Выводим результаты
    RAISE NOTICE 'РЕЗУЛЬТАТЫ МАССОВОЙ ВСТАВКИ';
    RAISE NOTICE 'Вставлено записей: %', records_count;
    RAISE NOTICE 'Время выполнения: % секунд', 
        EXTRACT(epoch FROM end_time - start_time);
    RAISE NOTICE 'LSN начало: %', start_lsn;
    RAISE NOTICE 'LSN конец:  %', end_lsn;
    RAISE NOTICE 'WAL сгенерировано: % KB', round(bytes_generated / 1024.0, 2);
END $$;

-- Итоговое состояние
SELECT 
    'КОНЕЦ ЭКСПЕРИМЕНТА' as этап,
    pg_current_wal_insert_lsn() as lsn_end,
    pg_walfile_name(pg_current_wal_insert_lsn()) as wal_file,
    (SELECT count(*) FROM pg_ls_waldir()) as files_count,
    (SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir()) as total_wal_size;

-- Размер таблицы теперь
SELECT 
    'Размер таблицы' as параметр,
    pg_size_pretty(pg_relation_size('wal_test')) as размер,
    pg_size_pretty(pg_total_relation_size('wal_test')) as полный_размер_с_индексами;
    
   