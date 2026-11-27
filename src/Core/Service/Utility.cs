
using Cloud5mins.ShortenerTools.Core.Domain;
using Cloud5mins.ShortenerTools.Core.Service;
using System.Security.Cryptography;
using CsvHelper;
using System.Globalization;
using CsvHelper.Configuration;



namespace Cloud5mins.ShortenerTools;
public static class Utility
{
    //reshuffled for randomisation, same unique characters just jumbled up, you can replace with your own version
    private const string ConversionCode = "FjTG0s5dgWkbLf_8etOZqMzNhmp7u6lUJoXIDiQB9-wRxCKyrPcv4En3Y21aASHV";

    public const int DefaultCodeLength = 7;
    public const int MinCodeLength = 4;
    public const int MaxCodeLength = 32;
    private const int MaxAttempts = 10;

    // Length of generated (non-vanity) codes. The value saved from the admin tool wins over
    // the "NonVanityCodeLength" app setting, which wins over the default.
    public static int GetCodeLength(int? savedLength = null)
    {
        if (savedLength is null && int.TryParse(Environment.GetEnvironmentVariable("NonVanityCodeLength"), out var configured))
            savedLength = configured;

        return Math.Clamp(savedLength ?? DefaultCodeLength, MinCodeLength, MaxCodeLength);
    }

    public static async Task<string> GetValidEndUrl(string vanity, IAzStrorageTablesService stgHelper)
    {
        if (!string.IsNullOrEmpty(vanity))
            return vanity;

        var settings = await stgHelper.GetSettingsEntity();
        var length = GetCodeLength(settings?.NonVanityCodeLength);
        for (var attempt = 0; attempt < MaxAttempts; attempt++)
        {
            var code = GenerateRandomCode(length);
            if (!await stgHelper.IfShortUrlEntityExistByVanity(code))
                return code;
        }

        throw new InvalidOperationException("Unable to generate a unique short code.");
    }

    public static string GetShortUrl(string host, string vanity)
    {
        return host + "/" + vanity;
    }

    // Purely random code (no sequential part), unbiased selection from the alphabet.
    public static string GenerateRandomCode(int length)
    {
        return string.Create(length, 0, (span, _) =>
        {
            for (var i = 0; i < span.Length; i++)
                span[i] = ConversionCode[RandomNumberGenerator.GetInt32(ConversionCode.Length)];
        });
    }


    public async static Task<UrlDetails> ExtractUrlsDataFromCSV(string fileFullName)
    {
        var data = new UrlDetails
        {
            NextId = new NextId(),
            LstShortUrlEntity = new List<ShortUrlEntity>()
        };

        if (fileFullName != null)
        {
            using (var reader = new StreamReader(fileFullName))
            {
                var csvConfig = new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    HeaderValidated = null,
                    MissingFieldFound = null,
                    // Treat whitespace-only cells (e.g. an empty Clicks column) as empty so they default to 0
                    TrimOptions = TrimOptions.Trim
                };

                using (var csv = new CsvReader(reader, csvConfig))
                {
                    csv.Read();
                    csv.ReadHeader();
                    while (csv.Read())
                    {
                        var rowKey = csv.GetField<string>("RowKey");
                        if (rowKey == "KEY")
                        {
                            data.NextId = new NextId
                            {
                                PartitionKey = csv.GetField("PartitionKey") ?? String.Empty,
                                RowKey = csv.GetField("RowKey") ?? String.Empty,
                                Id = csv.GetField<int>("Id")
                            };
                        }
                        else
                        {
                            var record = new ShortUrlEntity
                            {
                                PartitionKey = csv.GetField("PartitionKey") ?? String.Empty,
                                RowKey = csv.GetField("RowKey") ?? String.Empty,
                                Clicks = csv.GetField<int?>("Clicks") ?? 0,
                                Title = csv.GetField("Title") ?? String.Empty,
                                Url = csv.GetField("Url") ?? String.Empty,
                                SchedulesPropertyRaw = csv.GetField("SchedulesPropertyRaw") ?? String.Empty,
                                IsArchived = csv.GetField<bool?>("IsArchived") ?? false
                            };
                            data.LstShortUrlEntity.Add(record);
                        }
                    }
                }
            }
        }
        return data;
    }


    public async static Task<List<ClickStatsEntity>> ExtractClickStatsFromCSV(string fileFullName)
    {
        var lstClickStats = new List<ClickStatsEntity>();

        if (fileFullName != null)
        {
            using (var reader = new StreamReader(fileFullName))
            {
                var csvConfig = new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    HeaderValidated = null,
                    MissingFieldFound = null
                };
                using (var csv = new CsvReader(reader, csvConfig))
                {
                    var tempData = csv.GetRecords<ClickStatsEntity>();
                    lstClickStats = tempData.ToList<ClickStatsEntity>();
                }
            }
        }
        return lstClickStats;
    }
}
