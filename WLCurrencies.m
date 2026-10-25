#import "WLCurrencies.h"
#import "WLLang.h"

static const struct { const char *code; NSString *pl, *en, *ru; } kCur[] = {
    { "AED", @"Dirham ZEA", @"UAE dirham", @"Дирхам ОАЭ" },
    { "AFN", @"Afgani", @"Afghan afghani", @"Афгани" },
    { "ALL", @"Lek albański", @"Albanian lek", @"Албанский лек" },
    { "AMD", @"Dram ormiański", @"Armenian dram", @"Армянский драм" },
    { "ANG", @"Gulden antylski", @"Netherlands Antillean guilder", @"Нидерландский антильский гульден" },
    { "AOA", @"Kwanza", @"Angolan kwanza", @"Ангольская кванза" },
    { "ARS", @"Peso argentyńskie", @"Argentine peso", @"Аргентинское песо" },
    { "AUD", @"Dolar australijski", @"Australian dollar", @"Австралийский доллар" },
    { "AWG", @"Florin arubański", @"Aruban florin", @"Арубанский флорин" },
    { "AZN", @"Manat azerski", @"Azerbaijani manat", @"Азербайджанский манат" },
    { "BAM", @"Marka zamienna", @"Bosnia-Herzegovina mark", @"Конвертируемая марка" },
    { "BBD", @"Dolar barbadoski", @"Barbadian dollar", @"Барбадосский доллар" },
    { "BDT", @"Taka", @"Bangladeshi taka", @"Бангладешская така" },
    { "BGN", @"Lew bułgarski", @"Bulgarian lev", @"Болгарский лев" },
    { "BHD", @"Dinar bahrajski", @"Bahraini dinar", @"Бахрейнский динар" },
    { "BIF", @"Frank burundyjski", @"Burundian franc", @"Бурундийский франк" },
    { "BMD", @"Dolar bermudzki", @"Bermudian dollar", @"Бермудский доллар" },
    { "BND", @"Dolar brunejski", @"Brunei dollar", @"Брунейский доллар" },
    { "BOB", @"Boliviano", @"Bolivian boliviano", @"Боливийский боливиано" },
    { "BRL", @"Real brazylijski", @"Brazilian real", @"Бразильский реал" },
    { "BSD", @"Dolar bahamski", @"Bahamian dollar", @"Багамский доллар" },
    { "BTN", @"Ngultrum", @"Bhutanese ngultrum", @"Бутанский нгултрум" },
    { "BWP", @"Pula", @"Botswana pula", @"Ботсванская пула" },
    { "BYN", @"Rubel białoruski", @"Belarusian ruble", @"Белорусский рубль" },
    { "BZD", @"Dolar belizeński", @"Belize dollar", @"Белизский доллар" },
    { "CAD", @"Dolar kanadyjski", @"Canadian dollar", @"Канадский доллар" },
    { "CDF", @"Frank kongijski", @"Congolese franc", @"Конголезский франк" },
    { "CHF", @"Frank szwajcarski", @"Swiss franc", @"Швейцарский франк" },
    { "CLP", @"Peso chilijskie", @"Chilean peso", @"Чилийское песо" },
    { "CNY", @"Juan chiński", @"Chinese yuan", @"Китайский юань" },
    { "COP", @"Peso kolumbijskie", @"Colombian peso", @"Колумбийское песо" },
    { "CRC", @"Colon kostarykański", @"Costa Rican colón", @"Коста-риканский колон" },
    { "CUP", @"Peso kubańskie", @"Cuban peso", @"Кубинское песо" },
    { "CVE", @"Escudo Zielonego Przylądka", @"Cape Verdean escudo", @"Эскудо Кабо-Верде" },
    { "CZK", @"Korona czeska", @"Czech koruna", @"Чешская крона" },
    { "DJF", @"Frank dżibutyjski", @"Djiboutian franc", @"Франк Джибути" },
    { "DKK", @"Korona duńska", @"Danish krone", @"Датская крона" },
    { "DOP", @"Peso dominikańskie", @"Dominican peso", @"Доминиканское песо" },
    { "DZD", @"Dinar algierski", @"Algerian dinar", @"Алжирский динар" },
    { "EGP", @"Funt egipski", @"Egyptian pound", @"Египетский фунт" },
    { "ERN", @"Nakfa", @"Eritrean nakfa", @"Эритрейская накфа" },
    { "ETB", @"Birr", @"Ethiopian birr", @"Эфиопский быр" },
    { "EUR", @"Euro", @"Euro", @"Евро" },
    { "FJD", @"Dolar fidżyjski", @"Fijian dollar", @"Фиджийский доллар" },
    { "FKP", @"Funt falklandzki", @"Falkland Islands pound", @"Фунт Фолклендских островов" },
    { "FOK", @"Korona farerska", @"Faroese króna", @"Фарерская крона" },
    { "GBP", @"Funt szterling", @"British pound", @"Британский фунт" },
    { "GEL", @"Lari", @"Georgian lari", @"Грузинский лари" },
    { "GGP", @"Funt Guernsey", @"Guernsey pound", @"Фунт Гернси" },
    { "GHS", @"Cedi ghańskie", @"Ghanaian cedi", @"Ганский седи" },
    { "GIP", @"Funt gibraltarski", @"Gibraltar pound", @"Гибралтарский фунт" },
    { "GMD", @"Dalasi", @"Gambian dalasi", @"Гамбийский даласи" },
    { "GNF", @"Frank gwinejski", @"Guinean franc", @"Гвинейский франк" },
    { "GTQ", @"Quetzal", @"Guatemalan quetzal", @"Гватемальский кетсаль" },
    { "GYD", @"Dolar gujański", @"Guyanese dollar", @"Гайанский доллар" },
    { "HKD", @"Dolar hongkoński", @"Hong Kong dollar", @"Гонконгский доллар" },
    { "HNL", @"Lempira", @"Honduran lempira", @"Гондурасская лемпира" },
    { "HRK", @"Kuna chorwacka", @"Croatian kuna", @"Хорватская куна" },
    { "HTG", @"Gourde", @"Haitian gourde", @"Гаитянский гурд" },
    { "HUF", @"Forint", @"Hungarian forint", @"Венгерский форинт" },
    { "IDR", @"Rupia indonezyjska", @"Indonesian rupiah", @"Индонезийская рупия" },
    { "ILS", @"Szekel", @"Israeli shekel", @"Израильский шекель" },
    { "IMP", @"Funt manx", @"Manx pound", @"Фунт острова Мэн" },
    { "INR", @"Rupia indyjska", @"Indian rupee", @"Индийская рупия" },
    { "IQD", @"Dinar iracki", @"Iraqi dinar", @"Иракский динар" },
    { "IRR", @"Rial irański", @"Iranian rial", @"Иранский риал" },
    { "ISK", @"Korona islandzka", @"Icelandic króna", @"Исландская крона" },
    { "JEP", @"Funt Jersey", @"Jersey pound", @"Фунт Джерси" },
    { "JMD", @"Dolar jamajski", @"Jamaican dollar", @"Ямайский доллар" },
    { "JOD", @"Dinar jordański", @"Jordanian dinar", @"Иорданский динар" },
    { "JPY", @"Jen", @"Japanese yen", @"Японская иена" },
    { "KES", @"Szyling kenijski", @"Kenyan shilling", @"Кенийский шиллинг" },
    { "KGS", @"Som kirgiski", @"Kyrgyzstani som", @"Киргизский сом" },
    { "KHR", @"Riel", @"Cambodian riel", @"Камбоджийский риель" },
    { "KID", @"Dolar Kiribati", @"Kiribati dollar", @"Доллар Кирибати" },
    { "KMF", @"Frank komoryjski", @"Comorian franc", @"Коморский франк" },
    { "KRW", @"Won południowokoreański", @"South Korean won", @"Южнокорейская вона" },
    { "KWD", @"Dinar kuwejcki", @"Kuwaiti dinar", @"Кувейтский динар" },
    { "KYD", @"Dolar kajmański", @"Cayman Islands dollar", @"Доллар Островов Кайман" },
    { "KZT", @"Tenge", @"Kazakhstani tenge", @"Казахстанский тенге" },
    { "LAK", @"Kip", @"Lao kip", @"Лаосский кип" },
    { "LBP", @"Funt libański", @"Lebanese pound", @"Ливанский фунт" },
    { "LKR", @"Rupia lankijska", @"Sri Lankan rupee", @"Шри-ланкийская рупия" },
    { "LRD", @"Dolar liberyjski", @"Liberian dollar", @"Либерийский доллар" },
    { "LSL", @"Loti", @"Lesotho loti", @"Лоти" },
    { "LYD", @"Dinar libijski", @"Libyan dinar", @"Ливийский динар" },
    { "MAD", @"Dirham marokański", @"Moroccan dirham", @"Марокканский дирхам" },
    { "MDL", @"Lej mołdawski", @"Moldovan leu", @"Молдавский лей" },
    { "MGA", @"Ariary", @"Malagasy ariary", @"Малагасийский ариари" },
    { "MKD", @"Denar macedoński", @"Macedonian denar", @"Македонский денар" },
    { "MMK", @"Kiat", @"Myanmar kyat", @"Мьянманский кьят" },
    { "MNT", @"Tugrik", @"Mongolian tögrög", @"Монгольский тугрик" },
    { "MOP", @"Pataka", @"Macanese pataca", @"Патака Макао" },
    { "MRU", @"Ugia", @"Mauritanian ouguiya", @"Мавританская угия" },
    { "MUR", @"Rupia maurytyjska", @"Mauritian rupee", @"Маврикийская рупия" },
    { "MVR", @"Rufiyaa", @"Maldivian rufiyaa", @"Мальдивская руфия" },
    { "MWK", @"Kwacha malawijska", @"Malawian kwacha", @"Малавийская квача" },
    { "MXN", @"Peso meksykańskie", @"Mexican peso", @"Мексиканское песо" },
    { "MYR", @"Ringgit", @"Malaysian ringgit", @"Малайзийский ринггит" },
    { "MZN", @"Metical", @"Mozambican metical", @"Мозамбикский метикал" },
    { "NAD", @"Dolar namibijski", @"Namibian dollar", @"Намибийский доллар" },
    { "NGN", @"Naira", @"Nigerian naira", @"Нигерийская найра" },
    { "NIO", @"Cordoba", @"Nicaraguan córdoba", @"Никарагуанская кордоба" },
    { "NOK", @"Korona norweska", @"Norwegian krone", @"Норвежская крона" },
    { "NPR", @"Rupia nepalska", @"Nepalese rupee", @"Непальская рупия" },
    { "NZD", @"Dolar nowozelandzki", @"New Zealand dollar", @"Новозеландский доллар" },
    { "OMR", @"Rial omański", @"Omani rial", @"Оманский риал" },
    { "PAB", @"Balboa", @"Panamanian balboa", @"Панамский бальбоа" },
    { "PEN", @"Sol peruwiański", @"Peruvian sol", @"Перуанский соль" },
    { "PGK", @"Kina", @"Papua New Guinean kina", @"Кина" },
    { "PHP", @"Peso filipińskie", @"Philippine peso", @"Филиппинское песо" },
    { "PKR", @"Rupia pakistańska", @"Pakistani rupee", @"Пакистанская рупия" },
    { "PLN", @"Złoty", @"Polish złoty", @"Польский злотый" },
    { "PYG", @"Guarani", @"Paraguayan guaraní", @"Парагвайский гуарани" },
    { "QAR", @"Rial katarski", @"Qatari riyal", @"Катарский риал" },
    { "RON", @"Lej rumuński", @"Romanian leu", @"Румынский лей" },
    { "RSD", @"Dinar serbski", @"Serbian dinar", @"Сербский динар" },
    { "RUB", @"Rubel rosyjski", @"Russian ruble", @"Российский рубль" },
    { "RWF", @"Frank rwandyjski", @"Rwandan franc", @"Руандийский франк" },
    { "SAR", @"Rial saudyjski", @"Saudi riyal", @"Саудовский риял" },
    { "SBD", @"Dolar Wysp Salomona", @"Solomon Islands dollar", @"Доллар Соломоновых Островов" },
    { "SCR", @"Rupia seszelska", @"Seychellois rupee", @"Сейшельская рупия" },
    { "SDG", @"Funt sudański", @"Sudanese pound", @"Суданский фунт" },
    { "SEK", @"Korona szwedzka", @"Swedish krona", @"Шведская крона" },
    { "SGD", @"Dolar singapurski", @"Singapore dollar", @"Сингапурский доллар" },
    { "SHP", @"Funt Świętej Heleny", @"Saint Helena pound", @"Фунт Святой Елены" },
    { "SLE", @"Leone", @"Sierra Leonean leone", @"Леоне" },
    { "SLL", @"Leone (dawny)", @"Sierra Leonean leone (old)", @"Леоне (старый)" },
    { "SOS", @"Szyling somalijski", @"Somali shilling", @"Сомалийский шиллинг" },
    { "SRD", @"Dolar surinamski", @"Surinamese dollar", @"Суринамский доллар" },
    { "SSP", @"Funt południowosudański", @"South Sudanese pound", @"Южносуданский фунт" },
    { "STN", @"Dobra", @"São Tomé and Príncipe dobra", @"Добра" },
    { "SYP", @"Funt syryjski", @"Syrian pound", @"Сирийский фунт" },
    { "SZL", @"Lilangeni", @"Swazi lilangeni", @"Свазилендский лилангени" },
    { "THB", @"Bat", @"Thai baht", @"Тайский бат" },
    { "TJS", @"Somoni", @"Tajikistani somoni", @"Таджикский сомони" },
    { "TMT", @"Manat turkmeński", @"Turkmenistani manat", @"Туркменский манат" },
    { "TND", @"Dinar tunezyjski", @"Tunisian dinar", @"Тунисский динар" },
    { "TOP", @"Pa'anga", @"Tongan paʻanga", @"Тонганская паанга" },
    { "TRY", @"Lira turecka", @"Turkish lira", @"Турецкая лира" },
    { "TTD", @"Dolar Trynidadu i Tobago", @"Trinidad and Tobago dollar", @"Доллар Тринидада и Тобаго" },
    { "TVD", @"Dolar Tuvalu", @"Tuvaluan dollar", @"Доллар Тувалу" },
    { "TWD", @"Dolar tajwański", @"New Taiwan dollar", @"Новый тайваньский доллар" },
    { "TZS", @"Szyling tanzański", @"Tanzanian shilling", @"Танзанийский шиллинг" },
    { "UAH", @"Hrywna", @"Ukrainian hryvnia", @"Украинская гривна" },
    { "UGX", @"Szyling ugandyjski", @"Ugandan shilling", @"Угандийский шиллинг" },
    { "USD", @"Dolar amerykański", @"US dollar", @"Доллар США" },
    { "UYU", @"Peso urugwajskie", @"Uruguayan peso", @"Уругвайское песо" },
    { "UZS", @"Sum uzbecki", @"Uzbekistani soʻm", @"Узбекский сум" },
    { "VES", @"Boliwar wenezuelski", @"Venezuelan bolívar", @"Венесуэльский боливар" },
    { "VND", @"Dong", @"Vietnamese đồng", @"Вьетнамский донг" },
    { "VUV", @"Vatu", @"Vanuatu vatu", @"Вату" },
    { "WST", @"Tala", @"Samoan tālā", @"Самоанская тала" },
    { "XAF", @"Frank CFA (Afryka Środkowa)", @"Central African CFA franc", @"Франк КФА (Центральная Африка)" },
    { "XCD", @"Dolar wschodniokaraibski", @"East Caribbean dollar", @"Восточно-карибский доллар" },
    { "XCG", @"Gulden karaibski", @"Caribbean guilder", @"Карибский гульден" },
    { "XDR", @"SDR (MFW)", @"Special Drawing Rights (IMF)", @"СДР (МВФ)" },
    { "XOF", @"Frank CFA (Afryka Zachodnia)", @"West African CFA franc", @"Франк КФА (Западная Африка)" },
    { "XPF", @"Frank CFP", @"CFP franc", @"Франк КФП" },
    { "YER", @"Rial jemeński", @"Yemeni rial", @"Йеменский риал" },
    { "ZAR", @"Rand", @"South African rand", @"Южноафриканский рэнд" },
    { "ZMW", @"Kwacha zambijska", @"Zambian kwacha", @"Замбийская квача" },
    { "ZWL", @"Dolar zimbabwe", @"Zimbabwean dollar", @"Доллар Зимбабве" },
};

#define NCUR (sizeof(kCur) / sizeof(kCur[0]))

static NSDictionary *Index(void)
{
    static NSDictionary *d;
    if (!d) {
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        for (size_t i = 0; i < NCUR; i++) {
            [m setObject:[NSNumber numberWithUnsignedLong:(unsigned long)i] forKey:[NSString stringWithUTF8String:kCur[i].code]];
        }
        d = m;
    }
    return d;
}

NSString *WLCurrencyName(NSString *code)
{
    NSNumber *n = [Index() objectForKey:code];
    if (!n) return code;
    size_t i = (size_t)[n unsignedLongValue];
    switch (WLLanguage()) {
        case 1: return kCur[i].en;
        case 2: return kCur[i].ru;
        default: return kCur[i].pl;
    }
}

NSString *WLCurrencySearchText(NSString *code)
{
    NSNumber *n = [Index() objectForKey:code];
    if (!n) return code;
    size_t i = (size_t)[n unsignedLongValue];
    return [NSString stringWithFormat:@"%@ %@ %@ %@", code, kCur[i].pl, kCur[i].en, kCur[i].ru];
}
