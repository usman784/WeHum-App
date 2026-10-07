/// ISO 3166-1 alpha-2 → English name for the country lists (world map, lobby, dedications). Unknown codes show the code.
const _names = <String, String>{
  'AE': 'United Arab Emirates', 'AL': 'Albania', 'AM': 'Armenia', 'AR': 'Argentina', 'AT': 'Austria', 'AU': 'Australia', 'AZ': 'Azerbaijan', 'BA': 'Bosnia and Herzegovina',
  'BD': 'Bangladesh', 'BE': 'Belgium', 'BG': 'Bulgaria', 'BH': 'Bahrain', 'BO': 'Bolivia', 'BR': 'Brazil', 'BY': 'Belarus', 'CA': 'Canada', 'CH': 'Switzerland', 'CL': 'Chile',
  'CN': 'China', 'CO': 'Colombia', 'CR': 'Costa Rica', 'CY': 'Cyprus', 'CZ': 'Czechia', 'DE': 'Germany', 'DK': 'Denmark', 'DO': 'Dominican Republic', 'DZ': 'Algeria',
  'EC': 'Ecuador', 'EE': 'Estonia', 'EG': 'Egypt', 'ES': 'Spain', 'ET': 'Ethiopia', 'FI': 'Finland', 'FR': 'France', 'GB': 'United Kingdom', 'GE': 'Georgia', 'GH': 'Ghana',
  'GR': 'Greece', 'GT': 'Guatemala', 'HK': 'Hong Kong', 'HR': 'Croatia', 'HU': 'Hungary', 'ID': 'Indonesia', 'IE': 'Ireland', 'IL': 'Israel', 'IN': 'India', 'IQ': 'Iraq',
  'IR': 'Iran', 'IS': 'Iceland', 'IT': 'Italy', 'JM': 'Jamaica', 'JO': 'Jordan', 'JP': 'Japan', 'KE': 'Kenya', 'KR': 'South Korea', 'KW': 'Kuwait', 'KZ': 'Kazakhstan',
  'LB': 'Lebanon', 'LK': 'Sri Lanka', 'LT': 'Lithuania', 'LU': 'Luxembourg', 'LV': 'Latvia', 'MA': 'Morocco', 'MD': 'Moldova', 'MT': 'Malta', 'MX': 'Mexico', 'MY': 'Malaysia',
  'NG': 'Nigeria', 'NL': 'Netherlands', 'NO': 'Norway', 'NP': 'Nepal', 'NZ': 'New Zealand', 'OM': 'Oman', 'PA': 'Panama', 'PE': 'Peru', 'PH': 'Philippines', 'PK': 'Pakistan',
  'PL': 'Poland', 'PR': 'Puerto Rico', 'PT': 'Portugal', 'QA': 'Qatar', 'RO': 'Romania', 'RS': 'Serbia', 'RU': 'Russia', 'SA': 'Saudi Arabia', 'SE': 'Sweden', 'SG': 'Singapore',
  'SI': 'Slovenia', 'SK': 'Slovakia', 'TH': 'Thailand', 'TN': 'Tunisia', 'TR': 'Türkiye', 'TW': 'Taiwan', 'TZ': 'Tanzania', 'UA': 'Ukraine', 'UG': 'Uganda', 'US': 'United States',
  'UY': 'Uruguay', 'UZ': 'Uzbekistan', 'VE': 'Venezuela', 'VN': 'Vietnam', 'ZA': 'South Africa', 'ZW': 'Zimbabwe',
};

String countryName(String? code) => code == null ? '' : (_names[code.toUpperCase()] ?? code.toUpperCase());
