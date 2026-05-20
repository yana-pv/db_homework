using Npgsql;
using System.Text.Json;

namespace TaskQueueSystem;

public class OptimizedWorker
{
    private readonly int _workerId;
    private readonly DatabaseConfig _dbConfig;
    private readonly Random _random = new();
    private int _processedCount = 0;
    private int _failedCount = 0;
    private DateTime _lastStatsReport = DateTime.Now;

    public OptimizedWorker(int workerId, DatabaseConfig dbConfig)
    {
        _workerId = workerId;
        _dbConfig = dbConfig;
    }

    public async Task StartWorkingWithNotifyAsync(CancellationToken cancellationToken)
    {
        Console.WriteLine($"[OptimizedWorker {_workerId}] Запущен с поддержкой LISTEN/NOTIFY");

        await using var connection = new NpgsqlConnection(_dbConfig.GetConnectionString());
        await connection.OpenAsync(cancellationToken);

        // Подписываемся на уведомления
        connection.Notification += (sender, e) =>
        {
            Console.WriteLine($"[Worker {_workerId}] 📢 Получено уведомление о новой задаче: {e.Payload}");
        };

        const string listenSql = "LISTEN task_queue";
        await using (var listenCmd = new NpgsqlCommand(listenSql, connection))
        {
            await listenCmd.ExecuteNonQueryAsync(cancellationToken);
        }

        Console.WriteLine($"[OptimizedWorker {_workerId}] Ожидает уведомлений...");

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Ожидаем уведомления (блокирующая операция с таймаутом)
                await connection.WaitAsync(TimeSpan.FromSeconds(1), cancellationToken);

                // Пытаемся захватить задачу
                var task = await TryClaimTaskAsync(cancellationToken);
                if (task != null)
                {
                    await ProcessTaskAsync(task, cancellationToken);
                }

                // Периодический вывод статистики
                if ((DateTime.Now - _lastStatsReport).TotalSeconds >= 10)
                {
                    Console.WriteLine($"[OptimizedWorker {_workerId}] 📊 Обработано: {_processedCount}, Ошибок: {_failedCount}");
                    _lastStatsReport = DateTime.Now;
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (TimeoutException)
            {
                // Таймаут ожидания уведомления - продолжаем цикл
                continue;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[OptimizedWorker {_workerId}] ❌ Ошибка: {ex.Message}");
                await Task.Delay(1000, cancellationToken);
            }
        }

        Console.WriteLine($"[OptimizedWorker {_workerId}] Остановлен. Итого обработано: {_processedCount}");
    }

    private async Task<TaskModel?> TryClaimTaskAsync(CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(_dbConfig.GetConnectionString());
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
            SELECT id, task_type, payload, priority, status, attempts, created_at, scheduled_at
            FROM tasks
            WHERE status = 'Ready' AND scheduled_at <= NOW()
            ORDER BY priority DESC, scheduled_at ASC
            LIMIT 1
            FOR UPDATE SKIP LOCKED";

        await using var cmd = new NpgsqlCommand(sql, connection);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        if (await reader.ReadAsync(cancellationToken))
        {
            var task = new TaskModel
            {
                Id = reader.GetInt64(0),
                TaskType = reader.GetString(1),
                Payload = JsonDocument.Parse(reader.GetString(2)),
                Priority = reader.GetInt32(3),
                Status = reader.GetString(4),
                Attempts = reader.GetInt32(5),
                CreatedAt = reader.GetDateTime(6),
                ScheduledAt = reader.GetDateTime(7)
            };

            await reader.CloseAsync();

            const string updateSql = @"
                UPDATE tasks 
                SET status = 'Running', processing_started_at = NOW()
                WHERE id = @id";

            await using var updateCmd = new NpgsqlCommand(updateSql, connection);
            updateCmd.Parameters.AddWithValue("@id", task.Id);
            await updateCmd.ExecuteNonQueryAsync(cancellationToken);

            return task;
        }

        return null;
    }

    private async Task ProcessTaskAsync(TaskModel task, CancellationToken cancellationToken)
    {
        bool success = false;

        try
        {
            // Критические задачи обрабатываются быстрее
            var processingTime = task.Priority == 100 ? 50 : 200;
            await Task.Delay(processingTime, cancellationToken);

            // 5% случайных ошибок
            if (_random.NextDouble() < 0.05)
                throw new Exception("Симуляция ошибки обработки");

            success = true;
            Interlocked.Increment(ref _processedCount);

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"✓ [Worker {_workerId}] Задача #{task.Id} (Priority={task.Priority}) обработана за {processingTime}мс");
            Console.ResetColor();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            Interlocked.Increment(ref _failedCount);
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"✗ [Worker {_workerId}] Задача #{task.Id} провалилась: {ex.Message}");
            Console.ResetColor();
        }

        await UpdateTaskStatusAsync(task.Id, success, cancellationToken);
    }

    private async Task UpdateTaskStatusAsync(long taskId, bool success, CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(_dbConfig.GetConnectionString());
        await connection.OpenAsync(cancellationToken);

        string sql;
        if (success)
        {
            sql = @"UPDATE tasks 
                    SET status = 'Completed', 
                        processing_completed_at = NOW() 
                    WHERE id = @taskId";
        }
        else
        {
            sql = @"UPDATE tasks 
                    SET status = 'Ready', 
                        attempts = attempts + 1, 
                        scheduled_at = NOW() + INTERVAL '5 minutes',
                        error_message = 'Processing failed'
                    WHERE id = @taskId AND attempts < 3";
        }

        await using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@taskId", taskId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public int GetProcessedCount() => _processedCount;
    public int GetFailedCount() => _failedCount;
}