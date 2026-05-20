using Npgsql;
using System.Text.Json;
using System.Diagnostics;

namespace TaskQueueSystem;

public class Worker
{
    private readonly int _workerId;
    private readonly DatabaseConfig _dbConfig;
    private readonly Random _random = new();
    private int _processedCount = 0;
    private int _failedCount = 0;
    private int _criticalProcessed = 0;
    private int _regularProcessed = 0;

    public Worker(int workerId, DatabaseConfig dbConfig)
    {
        _workerId = workerId;
        _dbConfig = dbConfig;
    }

    public async Task StartWorkingAsync(CancellationToken cancellationToken = default)
    {
        Console.WriteLine($"[Worker {_workerId}] Запущен");

        await using var connection = new NpgsqlConnection(_dbConfig.GetConnectionString());
        await connection.OpenAsync(cancellationToken);

        // Подписываемся на уведомления
        connection.Notification += (sender, e) =>
        {
            // Уведомление получено - можно сразу забирать задачу
        };

        await using (var listenCmd = new NpgsqlCommand("LISTEN task_queue", connection))
        {
            await listenCmd.ExecuteNonQueryAsync(cancellationToken);
        }

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Ожидаем уведомление с таймаутом
                await connection.WaitAsync(TimeSpan.FromSeconds(1), cancellationToken);

                var task = await TryClaimTaskAsync(cancellationToken);
                if (task != null)
                {
                    await ProcessTaskAsync(task, cancellationToken);
                }
            }
            catch (TimeoutException)
            {
                // Продолжаем цикл
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"\n[Worker {_workerId}] Ошибка: {ex.Message}");
            }
        }

        Console.WriteLine($"\n[Worker {_workerId}] Остановлен. Обработано: {_processedCount} (Крит: {_criticalProcessed}, Обыч: {_regularProcessed})");
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
        var startTime = DateTime.UtcNow;

        try
        {
            // Критические задачи обрабатываются быстрее (50ms vs 200ms)
            var processingTime = task.Priority == 100 ? 50 : 200;
            await Task.Delay(processingTime, cancellationToken);

            // 5% случайных ошибок для демонстрации retry
            if (_random.NextDouble() < 0.05)
                throw new Exception("Симуляция ошибки обработки");

            success = true;
            Interlocked.Increment(ref _processedCount);
            if (task.Priority == 100) Interlocked.Increment(ref _criticalProcessed);
            else Interlocked.Increment(ref _regularProcessed);

            var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
            Console.ForegroundColor = ConsoleColor.Green;
            Console.Write($"✓[{task.Priority}]");
            Console.ResetColor();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            Interlocked.Increment(ref _failedCount);
            Console.ForegroundColor = ConsoleColor.Red;
            Console.Write($"✗[{task.Priority}]");
            Console.ResetColor();

            await UpdateTaskStatusAsync(task.Id, false, cancellationToken);
            return;
        }

        await UpdateTaskStatusAsync(task.Id, true, cancellationToken);
    }

    private async Task UpdateTaskStatusAsync(long taskId, bool success, CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(_dbConfig.GetConnectionString());
        await connection.OpenAsync(cancellationToken);

        string sql;
        if (success)
        {
            sql = @"UPDATE tasks 
                    SET status = 'Completed', processing_completed_at = NOW() 
                    WHERE id = @taskId";
        }
        else
        {
            sql = @"UPDATE tasks 
                    SET status = 'Ready', attempts = attempts + 1, 
                    scheduled_at = NOW() + INTERVAL '5 minutes',
                    error_message = 'Processing failed'
                    WHERE id = @taskId AND attempts < 3";
        }

        await using var cmd = new NpgsqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@taskId", taskId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public int GetProcessedCount() => _processedCount;
}