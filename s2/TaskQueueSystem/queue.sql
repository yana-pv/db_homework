CREATE TABLE IF NOT EXISTS tasks (
    id BIGSERIAL PRIMARY KEY,
    task_type VARCHAR(50) NOT NULL,
    payload JSONB,
    priority INT DEFAULT 0,           -- 0 = обычная, 100 = критическая
    status VARCHAR(20) DEFAULT 'Ready', -- Ready, Running, Completed, Failed
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    scheduled_at TIMESTAMP DEFAULT NOW(),
    processing_started_at TIMESTAMP,
    processing_completed_at TIMESTAMP,
    error_message TEXT
);

-- Индексы для оптимальной выборки задач
CREATE INDEX idx_tasks_status_priority_scheduled ON tasks(status, priority DESC, scheduled_at) 
WHERE status IN ('Ready', 'Running');

CREATE INDEX idx_tasks_created_at ON tasks(created_at);

-- Комментарии к полям
COMMENT ON COLUMN tasks.priority IS '0 - обычная, 100 - критическая';
COMMENT ON COLUMN tasks.status IS 'Ready, Running, Completed, Failed';
COMMENT ON COLUMN tasks.attempts IS 'Количество попыток выполнения';


-- Сколько задач упало с ошибкой
SELECT 
    attempts,
    COUNT(*) as count,
    MIN(scheduled_at) as earliest_retry,
    MAX(scheduled_at) as latest_retry
FROM tasks 
WHERE attempts > 0
GROUP BY attempts
ORDER BY attempts;


-- Доказательство работы Retry механизма
SELECT 
    id,
    priority,
    attempts,
    status,
    to_char(scheduled_at, 'HH24:MI:SS') as scheduled_at,
    error_message
FROM tasks 
WHERE attempts > 0
LIMIT 10;


-- Состояние таблицы ДО очистки
SELECT 
    pg_size_pretty(pg_total_relation_size('tasks')) as размер_таблицы,
    n_live_tup as живые_строки,
    n_dead_tup as мёртвые_строки,
    round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) as процент_раздувания
FROM pg_stat_all_tables 
WHERE relname = 'tasks';


VACUUM ANALYZE tasks;

-- Состояние таблицы ПОСЛЕ очистки
SELECT 
    pg_size_pretty(pg_total_relation_size('tasks')) as размер_таблицы,
    n_live_tup as живые_строки,
    n_dead_tup as мёртвые_строки,
    round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) as процент_раздувания
FROM pg_stat_all_tables 
WHERE relname = 'tasks';
