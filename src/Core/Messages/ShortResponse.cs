namespace Cloud5mins.ShortenerTools.Core.Messages
{
    public class ShortResponse
    {
        public string ShortUrl { get; set; } = string.Empty;
        public string LongUrl { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;

        public ShortResponse() { }
        public ShortResponse(string host, string longUrl, string endUrl, string title)
        {
            LongUrl = longUrl;
            ShortUrl = string.Concat(host, "/", endUrl);
            Title = title;

        }
    }
}