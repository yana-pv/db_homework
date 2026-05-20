using System.Text.Json;

namespace TaskQueueSystem;

public class TaskModel
{
    public long Id { get; set; }
    public string TaskType { get; set; } = string.Empty;
    public JsonDocument? Payload { get; set; }
    public int Priority { get; set; }
    public string Status { get; set; } = string.Empty;
    public int Attempts { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime ScheduledAt { get; set; }
}