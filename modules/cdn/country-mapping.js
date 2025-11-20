// Country to Continent Mapping
// This file contains the geo-location routing configuration for CloudFront Lambda@Edge
// Last Updated: 2025-01-21

module.exports = {
    // Continent to AWS Region Mapping
    regionMapping: {
        'EU': 'eu-central-1',
        'AS': 'ap-south-1',
        'NA': 'us-east-1',
        'SA': 'us-east-1',
        'OC': 'ap-south-1',
        'AF': 'eu-central-1'
    },

    // ISO 3166-1 Alpha-2 Country Codes to Continent Mapping
    countryToContinent: {
        // Europe (EU)
        'DE': 'EU', 'FR': 'EU', 'GB': 'EU', 'IT': 'EU', 'ES': 'EU', 'PL': 'EU',
        'RO': 'EU', 'NL': 'EU', 'BE': 'EU', 'GR': 'EU', 'CZ': 'EU', 'PT': 'EU',
        'SE': 'EU', 'HU': 'EU', 'AT': 'EU', 'CH': 'EU', 'BG': 'EU', 'DK': 'EU',
        'FI': 'EU', 'SK': 'EU', 'IE': 'EU', 'HR': 'EU', 'LT': 'EU', 'SI': 'EU',
        'LV': 'EU', 'EE': 'EU', 'CY': 'EU', 'LU': 'EU', 'MT': 'EU', 'IS': 'EU',
        'NO': 'EU', 'RS': 'EU', 'BA': 'EU', 'MK': 'EU', 'AL': 'EU', 'ME': 'EU',
        'XK': 'EU', 'MD': 'EU', 'UA': 'EU', 'BY': 'EU', 'RU': 'EU',

        // Asia (AS)
        'IN': 'AS', 'CN': 'AS', 'JP': 'AS', 'KR': 'AS', 'ID': 'AS', 'PK': 'AS',
        'BD': 'AS', 'PH': 'AS', 'VN': 'AS', 'TR': 'AS', 'IR': 'AS', 'TH': 'AS',
        'MM': 'AS', 'SA': 'AS', 'MY': 'AS', 'UZ': 'AS', 'IQ': 'AS', 'AF': 'AS',
        'NP': 'AS', 'YE': 'AS', 'KZ': 'AS', 'KH': 'AS', 'JO': 'AS', 'AE': 'AS',
        'IL': 'AS', 'HK': 'AS', 'LA': 'AS', 'SG': 'AS', 'OM': 'AS', 'KW': 'AS',
        'QA': 'AS', 'BH': 'AS', 'MN': 'AS', 'TM': 'AS', 'GE': 'AS', 'AM': 'AS',
        'AZ': 'AS', 'SY': 'AS', 'LB': 'AS', 'PS': 'AS', 'BT': 'AS', 'MV': 'AS',
        'LK': 'AS', 'TJ': 'AS', 'KG': 'AS', 'TW': 'AS', 'MO': 'AS', 'BN': 'AS',
        'TL': 'AS',

        // North America (NA)
        'US': 'NA', 'CA': 'NA', 'MX': 'NA', 'GT': 'NA', 'CU': 'NA', 'DO': 'NA',
        'HT': 'NA', 'HN': 'NA', 'NI': 'NA', 'CR': 'NA', 'PA': 'NA', 'BZ': 'NA',
        'SV': 'NA', 'JM': 'NA', 'TT': 'NA', 'BS': 'NA', 'BB': 'NA', 'LC': 'NA',
        'GD': 'NA', 'VC': 'NA', 'AG': 'NA', 'DM': 'NA', 'KN': 'NA',

        // South America (SA)
        'BR': 'SA', 'AR': 'SA', 'CO': 'SA', 'PE': 'SA', 'VE': 'SA', 'CL': 'SA',
        'EC': 'SA', 'BO': 'SA', 'PY': 'SA', 'UY': 'SA', 'GY': 'SA', 'SR': 'SA',
        'GF': 'SA',

        // Oceania (OC)
        'AU': 'OC', 'NZ': 'OC', 'PG': 'OC', 'FJ': 'OC', 'SB': 'OC', 'VU': 'OC',
        'NC': 'OC', 'PF': 'OC', 'WS': 'OC', 'KI': 'OC', 'FM': 'OC', 'TO': 'OC',
        'MH': 'OC', 'PW': 'OC', 'CK': 'OC', 'NU': 'OC', 'TK': 'OC', 'TV': 'OC',
        'NR': 'OC',

        // Africa (AF)
        'NG': 'AF', 'ET': 'AF', 'EG': 'AF', 'CD': 'AF', 'TZ': 'AF', 'ZA': 'AF',
        'KE': 'AF', 'UG': 'AF', 'DZ': 'AF', 'SD': 'AF', 'MA': 'AF', 'AO': 'AF',
        'MZ': 'AF', 'GH': 'AF', 'MG': 'AF', 'CM': 'AF', 'CI': 'AF', 'NE': 'AF',
        'BF': 'AF', 'ML': 'AF', 'MW': 'AF', 'ZM': 'AF', 'SN': 'AF', 'SO': 'AF',
        'TN': 'AF', 'SS': 'AF', 'TD': 'AF', 'LY': 'AF', 'LR': 'AF', 'SL': 'AF',
        'TG': 'AF', 'CF': 'AF', 'MR': 'AF', 'ER': 'AF', 'GM': 'AF', 'BW': 'AF',
        'GA': 'AF', 'LS': 'AF', 'GW': 'AF', 'GQ': 'AF', 'SZ': 'AF', 'DJ': 'AF',
        'RE': 'AF', 'KM': 'AF', 'CV': 'AF', 'SC': 'AF', 'ST': 'AF'
    },

    // Default fallback region
    defaultRegion: 'ap-south-1'
};
