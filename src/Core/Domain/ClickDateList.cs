namespace Cloud5mins.ShortenerTools.Core.Domain
{
    public class ClickDateList
    {
        public List<ClickDate> Items { get; set; } = new();
        public string Url { get; set; } = string.Empty;
        public ClickDateList()
        {
        }
        public ClickDateList(List<ClickDate> list)
        {
            Items = list;
            Url = string.Empty;
        }
    }
}