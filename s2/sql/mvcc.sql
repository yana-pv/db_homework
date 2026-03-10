-- 1. Смоделировать обновление данных и посмотреть на параметры xmin, xmax, ctid, t_infomask
SELECT 
    ctid,
    xmin::text,
    xmax::text,
    id,
    full_name,
    status
FROM employee 
LIMIT 3;

-- Обновляем сотрудника и возвращаем системные поля
UPDATE employee 
SET status = 'отпуск' 
WHERE id = 1 
RETURNING 
    ctid,
    xmin::text,
    xmax::text,
    id,
    full_name,
    status;

CREATE EXTENSION IF NOT EXISTS pageinspect;

-- Находим физическое расположение обновленной строки
SELECT ctid 
FROM employee 
WHERE id = 1;

SELECT 
    lp,
    t_infomask::integer,
    to_hex(t_infomask) AS t_infomask_hex
FROM heap_page_items(get_raw_page('employee', 0))
WHERE lp = 17;  



-- 3. Посмотреть на параметры из п1 в разных транзакциях
-- Сессия 1
BEGIN;

-- Запоминаем ID текущей транзакции
SELECT txid_current() AS transaction_id_1;

-- Обновляем сотрудника с id = 5
UPDATE employee 
SET status = 'отпуск' 
WHERE id = 5 
RETURNING id, full_name, status, ctid, xmin::text, xmax::text;

-- Запоминаем новый ctid 
SELECT ctid AS new_ctid FROM employee WHERE id = 5;

-- Сессия 2
BEGIN;

-- Читаем того же сотрудника
SELECT 
    id,
    full_name,
    status,
    ctid,
    xmin::text,
    xmax::text
FROM employee 
WHERE id = 5;

-- Сессия 1
COMMIT;

-- Сессия 2
-- Снова читаем того же сотрудника 
SELECT 
    id,
    full_name,
    status,
    ctid,
    xmin::text,
    xmax::text
FROM employee 
WHERE id = 5;

COMMIT;



-- 4. Смоделировать дедлок, описать результаты
-- Сессия 1
BEGIN;

-- Блокируем и обновляем сотрудника с id = 1
UPDATE employee 
SET status = 'отпуск' 
WHERE id = 1 
RETURNING id, full_name, status;

-- Сессия 2
BEGIN;

-- Блокируем и обновляем сотрудника с id = 2
UPDATE employee 
SET status = 'уволен' 
WHERE id = 2 
RETURNING id, full_name, status;

-- Сессия 1
-- Пытаемся обновить сотрудника с id = 2 (который заблокирован сессией 2)
UPDATE employee 
SET status = 'работает' 
WHERE id = 2 
RETURNING id, full_name, status;

-- Сессия 2
-- Пытаемся обновить сотрудника с id = 1 (который заблокирован сессией 1)
UPDATE employee 
SET status = 'работает' 
WHERE id = 1 
RETURNING id, full_name, status;