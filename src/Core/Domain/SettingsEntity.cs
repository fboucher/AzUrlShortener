using Azure;
using Azure.Data.Tables;

namespace Cloud5mins.ShortenerTools.Core.Domain;

// Single row holding the settings editable from the admin tool.
public class SettingsEntity : ITableEntity
{
    public const string Partition = "Settings";
    public const string Row = "Shortener";

    public int? NonVanityCodeLength { get; set; }
    public string PartitionKey { get; set; } = Partition;
    public string RowKey { get; set; } = Row;
    public DateTimeOffset? Timestamp { get; set; }
    public ETag ETag { get; set; }
}
