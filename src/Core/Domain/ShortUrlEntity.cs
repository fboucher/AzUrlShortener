using Azure;
using Azure.Data.Tables;
using System.Runtime.Serialization;
using System.Text.Json;


namespace Cloud5mins.ShortenerTools.Core.Domain
{
    public class ShortUrlEntity : ITableEntity
    {
        public string Url { get; set; } = string.Empty;
        private string _activeUrl { get; set; } = string.Empty;

        public string ActiveUrl
        {
            get
            {
                if (String.IsNullOrEmpty(_activeUrl))
                    _activeUrl = GetActiveUrl();
                return _activeUrl;
            }
        }


        public string Title { get; set; } = string.Empty;

        public string ShortUrl { get; set; } = string.Empty;

        public int Clicks { get; set; }

        public bool? IsArchived { get; set; }
        public string SchedulesPropertyRaw { get; set; } = string.Empty;

        private List<Schedule> _schedules { get; set; } = new();

        //[IgnoreProperty]
        [IgnoreDataMember]
        public List<Schedule> Schedules
        {
            get
            {
                if (_schedules == null)
                {
                    if (String.IsNullOrEmpty(SchedulesPropertyRaw))
                    {
                        _schedules = new List<Schedule>();
                    }
                    else
                    {
                        _schedules = JsonSerializer.Deserialize<Schedule[]>(SchedulesPropertyRaw)?.ToList() ?? new List<Schedule>();
                    }
                }
                return _schedules;
            }
            set
            {
                _schedules = value;
            }
        }

        public string PartitionKey { get; set; } = string.Empty;
        public string RowKey { get; set; } = string.Empty;
        public DateTimeOffset? Timestamp { get; set; }
        public ETag ETag { get; set; }

        public string CreatedDate { get; set; } = string.Empty;



        public ShortUrlEntity() { }

        public ShortUrlEntity(string longUrl, string endUrl)
        {
            Initialize(longUrl, endUrl, string.Empty, null);
        }

        public ShortUrlEntity(string longUrl, string endUrl, Schedule[]? schedules)
        {
            Initialize(longUrl, endUrl, string.Empty, schedules);
        }

        public ShortUrlEntity(string longUrl, string endUrl, string title, Schedule[]? schedules)
        {
            Initialize(longUrl, endUrl, title, schedules);
        }

        private void Initialize(string longUrl, string endUrl, string title, Schedule[]? schedules)
        {
            PartitionKey = endUrl.First().ToString();
            RowKey = endUrl;
            Url = longUrl;
            Title = title;
            Clicks = 0;
            IsArchived = false;
            CreatedDate = DateTime.UtcNow.ToString("yyyy-MM-dd");

            if (schedules?.Length > 0)
            {
                Schedules = schedules.ToList<Schedule>();
                SchedulesPropertyRaw = JsonSerializer.Serialize<List<Schedule>>(Schedules);
            }
        }


        // public static ShortUrlEntity GetEntity(string longUrl, string endUrl, string title, Schedule[] schedules)
        // {
        //     return new ShortUrlEntity
        //     {
        //         PartitionKey = endUrl.First().ToString(),
        //         RowKey = endUrl,
        //         Url = longUrl,
        //         Title = title,
        //         Schedules = schedules.ToList<Schedule>()
        //     };
        // }


        private string GetActiveUrl()
        {
            if (Schedules != null)
                return GetActiveUrl(DateTime.UtcNow);
            return Url;
        }
        private string GetActiveUrl(DateTime pointInTime)
        {
            var link = Url;
            var active = Schedules.Where(s =>
                s.End > pointInTime && //hasn't ended
                s.Start < pointInTime //already started
                ).OrderBy(s => s.Start); //order by start to process first link

            foreach (var sched in active.ToArray())
            {
                if (sched.IsActive(pointInTime))
                {
                    link = sched.AlternativeUrl;
                    break;
                }
            }
            return link;
        }

        public bool Validate()
        {
            //TODO: Add more validation
            if (string.IsNullOrEmpty(Url))
            {
                return false;
            }
            return true;
        }
    }

}