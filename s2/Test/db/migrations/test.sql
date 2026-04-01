-- 1 задание
explain ANALYZE
SELECT id, shop_id, total_sum, sold_at
FROM store_checks
WHERE shop_id = 77
  AND sold_at >= TIMESTAMP '2025-02-14 00:00:00'
  AND sold_at < TIMESTAMP '2025-02-15 00:00:00';

-- 1.png
-- использован Seq Scan
-- idx_store_checks_payment_type и idx_store_checks_total_sum_hash не помогают этому запросу
-- планировщик выбирает Seq Scan, потому что это наиболее быстрый способ, никакие существующие индексы не помогут сделать эфективнее
 
CREATE INDEX idx_store_checks_shop_id_sold_at ON store_checks (shop_id, sold_at);

EXPLAIN ANALYZE
SELECT id, shop_id, total_sum, sold_at
FROM store_checks
WHERE shop_id = 77
  AND sold_at >= TIMESTAMP '2025-02-14 00:00:00'
  AND sold_at < TIMESTAMP '2025-02-15 00:00:00';

-- 2.png
-- после создания индекса использован Index Scan и время выполнения запроса значительно уменьшилось, индексы в этос помогли 
-- ANALYZE нужен, чтобы обновить статистику и планирование запросов

analyze;


-- 2 задание
EXPLAIN ANALYZE
SELECT m.id, m.member_level, v.spend, v.visit_at
FROM club_members m
JOIN club_visits v ON v.member_id = m.id
WHERE m.member_level = 'premium'
  AND v.visit_at >= TIMESTAMP '2025-02-01 00:00:00'
  AND v.visit_at < TIMESTAMP '2025-02-10 00:00:00';

-- 3.png
-- использован Hash Join
-- idx_club_visits_visit_at полезен для фильтрации club_visits по дате
-- idx_club_members_full_name не используется

CREATE INDEX idx_club_members_member_level ON club_members (member_level);

EXPLAIN ANALYZE
SELECT m.id, m.member_level, v.spend, v.visit_at
FROM club_members m
JOIN club_visits v ON v.member_id = m.id
WHERE m.member_level = 'premium'
  AND v.visit_at >= TIMESTAMP '2025-02-01 00:00:00'
  AND v.visit_at < TIMESTAMP '2025-02-10 00:00:00';

-- 4.png
-- cost стал меньше, время выполнения уменьшилось, использован всё также Hash Join
-- по member_level = 'premium' раньше был Seq Scan, теперь Bitmap Heap Scan и Bitmap Index Scan
-- shared hit в BUFFERS показывапт сколько данных взялось из кэша
-- shared read показывает сколько данных прочиталось с диска

-- 3 задание
SELECT xmin, xmax, ctid, id, title, stock
FROM warehouse_items
ORDER BY id;

-- 6.png

UPDATE warehouse_items
SET stock = stock - 2
WHERE id = 1;

SELECT xmin, xmax, ctid, id, title, stock
FROM warehouse_items
ORDER BY id;

-- 7.png

DELETE FROM warehouse_items
WHERE id = 3;

SELECT xmin, xmax, ctid, id, title, stock
FROM warehouse_items
ORDER BY id;

-- 8.png

-- в первой строке изменился xmin, новая версия строки получила новый ctid 
-- Почему в модели MVCC UPDATE не является простым "перезаписыванием" строки
-- MVCC обеспечивает изоляцию транзакций, обеспечивает возможность отката транзакции 
-- VACUUM не освобождает место в операционной памяти
-- autovacuum делает VACUUM и analyze автоматически
-- VACUUM FULL блокирует всю таблицу и освобождает место в операционной памяти