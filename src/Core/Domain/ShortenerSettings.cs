namespace Cloud5mins.ShortenerTools.Core.Domain
{
    public class ShortenerSettings
    {
        public string DefaultRedirectUrl { get; set; } = string.Empty;
        public string CustomDomain { get; set; } = string.Empty;
        public string DataStorage { get; set; } = string.Empty;
    }
}