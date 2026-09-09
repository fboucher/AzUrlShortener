using Cloud5mins.ShortenerTools.Core.Domain;

namespace Cloud5mins.ShortenerTools.Core.Messages
{
    public class ShortRequest
    {
        public string Vanity { get; set; } = string.Empty;

        public string Url { get; set; } = string.Empty;

        public string Title { get; set; } = string.Empty;

        public Schedule[] Schedules { get; set; } = Array.Empty<Schedule>();
    }
}